package learning

// Event store and workspace persistence (section 10 of AGENTIC_LEARNING.md).
//
// - events.jsonl is the authoritative record; state.json is a replaceable
//   projection rebuilt by folding events.
// - Mutations run under a short-lived directory lock; the lock is never held
//   while waiting on a learner or remote judge (handlers do no I/O besides
//   these file writes inside the transaction).
// - Mutating requests carry a unique request_id and expected workspace
//   revision. Repeating an identical request returns its existing result;
//   reusing the id with a different payload fails.
// - Projections are written to a temp file and atomically renamed.
// - A truncated final record is preserved and reported; corruption in the
//   middle stops writes and requires repair.

import "core:crypto/sha2"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

join :: proc(parts: []string) -> string {
	p, _ := os.join_path(parts, context.allocator)
	return p
}

learning_dir  :: proc(ws: string) -> string { return join({ws, LEARNING_DIR}) }
events_path   :: proc(ws: string) -> string { return join({ws, LEARNING_DIR, EVENTS_FILE}) }
state_path    :: proc(ws: string) -> string { return join({ws, LEARNING_DIR, STATE_FILE}) }
manifest_path :: proc(ws: string) -> string { return join({ws, LEARNING_DIR, MANIFEST_FILE}) }
lock_path     :: proc(ws: string) -> string { return join({ws, LEARNING_DIR, LOCK_DIR}) }

// ensure_dirs creates the storage tree from section 10. Existing files are
// never touched.
ensure_dirs :: proc(ws: string) -> os.Error {
	subs := [?]string{"catalog", "sessions", "attempts", "artifacts", "jobs", "imports", "exports", "backups"}
	for sub in subs {
		dir := join({ws, LEARNING_DIR, sub})
		if e := os.make_directory_all(dir, os.perm(0o700)); e != nil && e != .Exist {
			return e
		}
	}
	return nil
}

// write_private_file writes 0600 via a sibling temp file and atomic rename,
// mirroring the credential writer in leetcode/config.odin. Failed writes
// leave the previous contents intact; symlinks are not followed.
write_private_file :: proc(path: string, data: string) -> (err: os.Error) {
	if e := os.make_directory_all(os.dir(path), os.perm(0o700)); e != nil && e != .Exist {
		return e
	}
	file := os.create_temp_file(os.dir(path), ".algolearn-write-*") or_return
	temporary := strings.clone(os.name(file))
	defer delete(temporary)
	defer os.remove(temporary)
	defer if file != nil {
		os.close(file)
	}
	os.fchmod(file, os.perm(0o600)) or_return
	written := os.write(file, transmute([]u8) data) or_return
	if written != len(data) { return .Invalid_Argument }
	err = os.close(file)
	file = nil
	if err != nil { return }
	return os.rename(temporary, path)
}

hash_hex :: proc(data: string) -> string {
	ctx: sha2.Context_256
	sha2.init_256(&ctx)
	sha2.update(&ctx, transmute([]u8) data)
	digest: [sha2.DIGEST_SIZE_256]u8
	sha2.final(&ctx, digest[:])
	s := ""
	for b in digest {
		s = fmt.aprintf("%s%02x", s, b)
	}
	return s
}

// -- store -----------------------------------------------------------------------

Store :: struct {
	workspace:    string,
	workspace_id: string,
	events:       [dynamic]Event,
	revision:     int, // highest applied sequence; 0 for an empty workspace
	tail_warning: string, // set when the final record is truncated/corrupt
}

load_store :: proc(workspace: string) -> (store: Store, err: Engine_Error) {
	store.workspace = workspace
	data, ferr := os.read_entire_file(events_path(workspace), context.allocator)
	if ferr != nil {
		if ferr == .Not_Exist { return store, .None }
		return store, .Storage_Error
	}
	defer delete(data)

	lines := strings.split_lines(string(data))
	defer delete(lines)
	for line, i in lines {
		if strings.trim_space(line) == "" { continue }
		ev, ok := parse_event(line)
		if !ok {
			if i == len(lines) - 1 {
				// Truncated final record: keep it on disk, surface a
				// warning, and refuse later writes until repaired.
				store.tail_warning = "the final event record is truncated and was preserved; writes are blocked until repair"
				break
			}
			fmt.eprintln("algolearn: corrupt event record at line", i + 1)
			return store, .Storage_Error
		}
		if store.workspace_id == "" { store.workspace_id = ev.workspace_id }
		append(&store.events, ev)
		store.revision = ev.sequence
	}
	return store, .None
}

parse_event :: proc(line: string) -> (ev: Event, ok: bool) {
	v, perr := json.parse(line, .JSON, parse_integers = true)
	if perr != nil { return ev, false }
	if _, is_obj := v.(json.Object); !is_obj { return ev, false }
	ev = Event{
		sequence     = jint(jget(v, "sequence")),
		event_id     = jstr(jget(v, "event_id")),
		workspace_id = jstr(jget(v, "workspace_id")),
		timestamp    = jstr(jget(v, "timestamp")),
		actor        = jstr(jget(v, "actor")),
		type         = jstr(jget(v, "type")),
		request_id   = jstr(jget(v, "request_id")),
		request_hash = jstr(jget(v, "request_hash")),
		session_id   = jstr(jget(v, "session_id")),
		attempt_id   = jstr(jget(v, "attempt_id")),
		payload      = "",
	}
	if raw := jget(v, "payload"); raw != nil {
		// Re-serialize deterministically; payload objects are small.
		if b, merr := json.marshal(raw); merr == nil {
			ev.payload = strings.clone(string(b))
			delete(b)
		}
	}
	return ev, true
}

// -- locking ----------------------------------------------------------------------

lock_workspace :: proc(ws: string) -> Engine_Error {
	// The storage tree must exist before the lock directory can be created;
	// this is a no-op for initialized workspaces.
	if derr0 := ensure_dirs(ws); derr0 != nil {
		fmt.eprintln("algolearn: cannot create learning directories:", os.error_string(derr0))
		return .Storage_Error
	}
	lp := lock_path(ws)
	derr := os.make_directory(lp, os.perm(0o700))
	if derr == .Exist {
		// A lock left by a crashed client is removed after the staleness
		// window; short transactions mean a live lock never ages that far.
		if info, serr := os.stat(lp, context.allocator); serr == nil {
			age := time.diff(info.modification_time, time.now())
			if age > time.Duration(LOCK_STALE_MINUTES) * time.Minute {
				os.remove(lp)
				derr = os.make_directory(lp, os.perm(0o700))
			}
		}
	}
	if derr == nil { return .None }
	if derr == .Exist {
		fmt.eprintln("algorearn: workspace is locked by another client")
		return .Workspace_Locked
	}
	return .Storage_Error
}

LOCK_STALE_MINUTES :: 10

unlock_workspace :: proc(ws: string) {
	if e := os.remove(lock_path(ws)); e != nil && e != .Not_Exist {
		fmt.eprintln("algolearn: failed to release lock:", os.error_string(e))
	}
}

// -- commit ------------------------------------------------------------------------

// commit_result reports the outcome of a mutation. `replayed` marks a repeated
// identical request; the original event is returned.
commit_event :: proc(
	store: ^Store,
	ev_type, actor: string,
	req: Request,
	session_id, attempt_id, payload: string,
) -> (ev: Event, err: Engine_Error, replayed: bool) {
	if lerr := lock_workspace(store.workspace); lerr != .None {
		return ev, lerr, false
	}
	// Short transaction: the lock is released on every exit path from here.
	defer unlock_workspace(store.workspace)

	// Reload under the lock so concurrent clients are seen.
	fresh, lerr := load_store(store.workspace)
	if lerr != .None { return ev, lerr, false }

	// Request deduplication: same id + same payload -> existing result;
	// same id + different payload -> conflict.
	if req.request_id != "" {
		for existing in fresh.events {
			if existing.request_id == req.request_id {
				if existing.request_hash == req.request_hash && existing.type == ev_type {
					return existing, .None, true
				}
				return ev, .Request_Conflict, false
			}
		}
	}

	// Revision check. req.expected_revision < 0 means "latest known" and is
	// accepted with a warning from the caller; concurrent writers must pass
	// the revision they loaded.
	if req.expected_revision >= 0 && req.expected_revision != fresh.revision {
		err = .Stale_Revision
		store.revision = fresh.revision
		return ev, err, false
	}
	if fresh.tail_warning != "" {
		// Corruption stops writes; do not silently drop the damaged tail.
		return ev, .Storage_Error, false
	}

	seq := fresh.revision + 1
	workspace_id := fresh.workspace_id
	if workspace_id == "" {
		// First event: stamp a stable identity derived from the workspace path.
		workspace_id = fmt.aprintf("ws_%s", hash_hex(store.workspace)[:24])
	}
	ev = Event{
		sequence     = seq,
		event_id     = fmt.aprintf("ev_%s_%06d", workspace_id[3:], seq),
		workspace_id = workspace_id,
		timestamp    = now_rfc3339(),
		actor        = actor,
		type         = ev_type,
		request_id   = req.request_id,
		request_hash = req.request_hash,
		session_id   = session_id,
		attempt_id   = attempt_id,
		payload      = payload,
	}

	// Rewrite the log atomically with the new event appended. Never rewrite
	// event bytes otherwise.
	content := make([dynamic]u8)
	defer delete(content)
	file_data, _ := os.read_entire_file(events_path(store.workspace), context.allocator)
	if file_data != nil {
		append(&content, string(file_data))
		delete(file_data)
	}
	append(&content, event_to_json(&ev))
	append(&content, '\n')
	if werr := write_private_file(events_path(store.workspace), string(content[:])); werr != nil {
		fmt.eprintln("algolearn: failed to append event:", os.error_string(werr))
		return ev, .Storage_Error, false
	}

	// Keep the caller's view current for folds and id minting.
	store.revision = seq
	store.workspace_id = workspace_id
	clear(&store.events)
	for e in fresh.events { append(&store.events, e) }
	append(&store.events, ev)

	return ev, .None, false
}
