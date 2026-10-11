package learning

// Event store and workspace persistence (section 10).
//
// - events.jsonl is authoritative; state.json is a replaceable projection.
// - Mutations run under a short-lived directory lock that is never held while
//   waiting on a learner or remote judge.
// - Mutating requests carry a unique request_id and expected revision. An
//   identical repeat returns the original event; reusing the id with a
//   different payload fails.
// - A truncated final record is preserved and reported; corruption earlier in
//   the log stops writes until repaired.

import "core:crypto/sha2"
import "core:encoding/hex"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "../../safeio"

LOCK_STALE_AFTER :: 10 * time.Minute

STORAGE_DIRS :: [?]string{"catalog", "sessions", "attempts", "artifacts", "jobs", "imports", "exports", "backups"}

Event :: struct {
	schema_version: int,
	event_id:       string,
	sequence:       int,
	workspace_id:   string,
	timestamp:      string, // RFC 3339 UTC
	actor:          string, // "agent:<host>" | "learner" | "tool" | "system"
	type:           string,
	request_id:     string,
	request_hash:   string, // hash of the full request text
	session_id:     string,
	attempt_id:     string,
	payload:        Raw_JSON,
}

Store :: struct {
	workspace:    string,
	workspace_id: string,
	events:       [dynamic]Event,
	revision:     int,    // highest applied sequence; 0 for an empty workspace
	tail_warning: string, // set when the final record is truncated
}

join :: proc(parts: ..string) -> string {
	return os.join_path(parts, context.allocator) or_else ""
}

learning_path :: proc(workspace: string, parts: ..string) -> string {
	all := make([dynamic]string, 0, len(parts) + 2)
	append(&all, workspace, LEARNING_DIR)
	append(&all, ..parts)
	return join(..all[:])
}

events_path :: proc(ws: string) -> string { return learning_path(ws, EVENTS_FILE) }
state_path :: proc(ws: string) -> string { return learning_path(ws, STATE_FILE) }
manifest_path :: proc(ws: string) -> string { return learning_path(ws, MANIFEST_FILE) }

write_private_file :: proc(path: string, data: string) -> os.Error {
	return safeio.write_private_file(path, transmute([]byte)data)
}

hash_hex :: proc(data: string) -> string {
	digest: [sha2.DIGEST_SIZE_256]byte
	ctx: sha2.Context_256
	sha2.init_256(&ctx)
	sha2.update(&ctx, transmute([]byte)data)
	sha2.final(&ctx, digest[:])
	return string(hex.encode(digest[:]))
}

workspace_id_for :: proc(workspace: string) -> string {
	return fmt.aprintf("ws_%s", hash_hex(workspace)[:24])
}

// ensure_dirs creates the storage tree; existing files are never touched.
ensure_dirs :: proc(ws: string) -> os.Error {
	for sub in STORAGE_DIRS {
		if err := os.make_directory_all(learning_path(ws, sub), os.perm(0o700)); err != nil && err != .Exist {
			return err
		}
	}
	return nil
}

load_store :: proc(workspace: string) -> (store: Store, err: Engine_Error) {
	store.workspace = workspace
	data, read_err := os.read_entire_file(events_path(workspace), context.allocator)
	if read_err == .Not_Exist {
		return store, nil
	} else if read_err != nil {
		return store, .Storage_Error
	}

	lines := strings.split_lines(string(data))
	for line, i in lines {
		if strings.trim_space(line) == "" {
			continue
		}
		ev, ok := parse_event(line)
		if !ok {
			if i == len(lines) - 1 {
				// Keep the truncated record on disk and refuse later writes.
				store.tail_warning = "the final event record is truncated and was preserved; writes are blocked until repair"
				break
			}
			fmt.eprintln("algolearn: corrupt event record at line", i + 1)
			return store, .Storage_Error
		}
		if store.workspace_id == "" {
			store.workspace_id = ev.workspace_id
		}
		append(&store.events, ev)
		store.revision = ev.sequence
	}
	return store, nil
}

// parse_event decodes one log line. A missing or null payload reads as an
// empty object; any other non-object payload is corrupt.
parse_event :: proc(line: string) -> (ev: Event, ok: bool) {
	if !decode(line, &ev) {
		return {}, false
	}
	switch {
	case ev.payload == "" || ev.payload == "null":
		ev.payload = EMPTY_OBJECT
	case !strings.has_prefix(string(ev.payload), "{"):
		return {}, false
	}
	return ev, true
}

// -- locking -------------------------------------------------------------------

lock_workspace :: proc(ws: string) -> Engine_Error {
	// The storage tree must exist before the lock directory can be created.
	if err := ensure_dirs(ws); err != nil {
		fmt.eprintln("algolearn: cannot create learning directories:", os.error_string(err))
		return .Storage_Error
	}
	lock := learning_path(ws, LOCK_DIR)
	err := os.make_directory(lock, os.perm(0o700))
	if err == .Exist {
		// A crashed client's lock is reclaimed after the staleness window;
		// transactions are short, so a live lock never ages that far.
		if info, stat_err := os.stat(lock, context.allocator); stat_err == nil && time.since(info.modification_time) > LOCK_STALE_AFTER {
			os.remove(lock)
			err = os.make_directory(lock, os.perm(0o700))
		}
	}
	switch {
	case err == nil:
		return nil
	case err == .Exist:
		fmt.eprintln("algolearn: workspace is locked by another client")
		return .Workspace_Locked
	}
	return .Storage_Error
}

unlock_workspace :: proc(ws: string) {
	if err := os.remove(learning_path(ws, LOCK_DIR)); err != nil && err != .Not_Exist {
		fmt.eprintln("algolearn: failed to release lock:", os.error_string(err))
	}
}

// -- commit --------------------------------------------------------------------

// commit_event appends one event under the workspace lock. replayed reports
// a repeated identical request, in which case the original event is returned.
commit_event :: proc(
	store: ^Store,
	type, actor: string,
	req: Request,
	session_id, attempt_id: string,
	payload: Raw_JSON,
) -> (ev: Event, replayed: bool, err: Engine_Error) {
	lock_workspace(store.workspace) or_return
	defer unlock_workspace(store.workspace)

	// Reload under the lock so concurrent clients are seen.
	fresh := load_store(store.workspace) or_return

	if req.request_id != "" {
		for existing in fresh.events {
			if existing.request_id != req.request_id {
				continue
			}
			if existing.request_hash == req.request_hash && existing.type == type {
				return existing, true, nil
			}
			return {}, false, .Request_Conflict
		}
	}
	// Concurrent writers pass the revision they loaded; < 0 accepts the latest.
	if req.expected_revision >= 0 && req.expected_revision != fresh.revision {
		store.revision = fresh.revision
		return {}, false, .Stale_Revision
	}
	if fresh.tail_warning != "" {
		// Never append after, and so silently drop, a damaged tail.
		return {}, false, .Storage_Error
	}

	sequence := fresh.revision + 1
	workspace_id := fresh.workspace_id if fresh.workspace_id != "" else workspace_id_for(store.workspace)
	ev = Event{
		schema_version = SCHEMA_VERSION,
		event_id       = fmt.aprintf("ev_%s_%06d", workspace_id[3:], sequence),
		sequence       = sequence,
		workspace_id   = workspace_id,
		timestamp      = now_rfc3339(),
		actor          = actor,
		type           = type,
		request_id     = req.request_id,
		request_hash   = req.request_hash,
		session_id     = session_id,
		attempt_id     = attempt_id,
		payload        = payload,
	}

	// Rewrite the log atomically with the event appended; existing event
	// bytes are copied unchanged.
	existing, _ := os.read_entire_file(events_path(store.workspace), context.allocator)
	content := strings.concatenate({string(existing), string(to_json(ev)), "\n"})
	if write_err := write_private_file(events_path(store.workspace), content); write_err != nil {
		fmt.eprintln("algolearn: failed to append event:", os.error_string(write_err))
		return {}, false, .Storage_Error
	}

	store.revision = sequence
	store.workspace_id = workspace_id
	store.events = fresh.events
	append(&store.events, ev)
	return ev, false, nil
}
