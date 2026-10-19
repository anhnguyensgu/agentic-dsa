package learn

// Conservative import/export and exact-scope deletion (sections 10 and 15).
// Provider credentials, caches, and full statements are never exported.

import "core:fmt"
import "core:os"
import "core:strings"

EXPORT_EXCLUSIONS :: [?]string {
	"provider_credentials",
	"provider_caches",
	"full_problem_statements",
}

// Remote authorization references and raw provider observations stay out of
// the portable history.
PRIVATE_EVENTS :: bit_set[Event_Type] {
	.Submission_Sent,
	.Submission_Outcome_Unknown,
	.Job_Observed,
	.Export_Created,
}

workspace_file :: proc(ctx: ^Context, relative: string) -> (string, bool) {
	if !safe_relative_path(relative) {
		return "", false
	}
	path := join(ctx.workspace, relative)
	if os.is_file(path) && !path_is_within_workspace(ctx.workspace, path) {
		return "", false
	}
	return path, true
}

// -- export_create -------------------------------------------------------------

Export_Create_Params :: struct {
	scope:          string, // profile_history (default) | handoff
	session_id:     string,
	include_source: bool,
}

Exported_Source :: struct {
	attempt_id:  string,
	source_path: string,
	source_hash: string,
	content:     string,
}

// A portable export. The handoff scope carries only handoff; the history
// scope carries everything after it.
Export :: struct {
	schema_version:     int,
	export_version:     string,
	export_id:          string,
	workspace_id:       string,
	workspace_revision: int,
	scope:              string,
	excluded:           []string,
	handoff:            Maybe(Raw_JSON) `json:",omitempty"`,
	profile:            Maybe(Raw_JSON) `json:",omitempty"`,
	sessions:           Maybe([]Session_View) `json:",omitempty"`,
	concepts:           Maybe([]Concept_View) `json:",omitempty"`,
	reviews:            Maybe([]Review_View) `json:",omitempty"`,
	attempts:           Maybe([]Attempt_View) `json:",omitempty"`,
	events:             Maybe([]Event) `json:",omitempty"`,
	sources:            Maybe([]Exported_Source) `json:",omitempty"`,
}

op_export_create :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Export_Create_Params) or_return
	scope := first_nonempty(p.scope, "profile_history")
	if scope != "profile_history" && scope != "handoff" {
		return {}, invalid("scope must be profile_history or handoff")
	}
	st := fold(store)
	exclusions := EXPORT_EXCLUSIONS
	export := Export {
		schema_version     = SCHEMA_VERSION,
		export_version     = "1",
		export_id          = fmt_id("export", store.revision + 1),
		workspace_id       = st.workspace_id,
		workspace_revision = st.revision,
		scope              = scope,
		excluded           = exclusions[:],
	}
	if scope == "handoff" {
		if p.session_id == "" {
			return {}, invalid("session_id is required for a handoff export")
		}
		handoff, found := session_handoff(store, p.session_id)
		if !found {
			return {}, fail(.Not_Found, "session does not exist")
		}
		export.handoff = handoff
	} else {
		events := make([]Event, len(store.events))
		for ev, i in store.events {
			events[i] = ev
			if is_event(ev, PRIVATE_EVENTS) {
				events[i].actor = "system"
				events[i].type = EVENT_TYPE_NAMES[.Private_Event_Redacted]
				events[i].payload = `{"redacted":true,"reason":"private_remote_metadata"}`
				events[i].attempt_id = ""
			}
		}
		export.profile = profile_view(st.profile)
		export.sessions = session_views(st.sessions[:])
		export.concepts = concept_views(st.concepts[:])
		export.reviews = review_views(st.reviews[:])
		export.attempts = attempt_views(st.attempts[:])
		export.events = events
		if p.include_source {
			sources := make([dynamic]Exported_Source)
			for a in st.attempts {
				if data, read_err := os.read_entire_file(
					join(ctx.workspace, a.source_path),
					context.allocator,
				); read_err == nil {
					append(
						&sources,
						Exported_Source{a.id, a.source_path, hash_hex(string(data)), string(data)},
					)
				}
			}
			export.sources = sources[:]
		}
	}
	document := to_json(export)

	path := join(LEARNING_DIR, "exports", strings.concatenate({export.export_id, ".json"}))
	if write_private_file(join(ctx.workspace, path), string(document)) != nil {
		return {}, fail(.Storage_Error, "could not write the export")
	}
	content_hash := hash_hex(string(document))
	ev, replayed := commit(
		ctx,
		store,
		req,
		.Export_Created,
		Export_Created{export.export_id, scope, path, content_hash},
	) or_return
	created := Export_Created{export.export_id, scope, path, content_hash}
	if replayed {
		decode(string(ev.payload), &created)
	}

	Data :: struct {
		replayed:     Replayed `json:",omitempty"`,
		export_id:    string,
		path:         string,
		content_hash: string,
		excluded:     []string,
	}
	res = mutation_result(replayed)
	res.data = to_json(
		Data {
			replayed_flag(replayed),
			created.export_id,
			created.path,
			created.content_hash,
			exclusions[:],
		},
	)
	return
}

// -- import_validate / import_apply --------------------------------------------

Import_Validate_Params :: struct {
	kind:     string, // legacy (default) | export
	path:     string,
	mappings: Raw_JSON,
}

Import_Apply_Params :: struct {
	kind:        string,
	source_hash: string,
	path:        string,
	mappings:    Raw_JSON,
}

Export_Document :: struct {
	schema_version: int,
	events:         []Raw_JSON,
	sources:        []Exported_Source,
}

// The legacy .algo files, or one explicitly named file.
legacy_paths :: proc(ctx: ^Context, requested: string) -> (paths: []string, ok: bool) {
	if requested != "" {
		path := workspace_file(ctx, requested) or_return
		paths = make([]string, 1)
		paths[0] = path
		return paths, true
	}
	paths = make([]string, 2)
	paths[0] = join(ctx.workspace, ".algo", "config.json")
	paths[1] = join(ctx.workspace, ".algo", "events.jsonl")
	return paths, true
}

// legacy_source_hash hashes the files (names included) and counts the legacy
// events that no mapping resolves.
legacy_source_hash :: proc(paths: []string) -> (hash: string, unresolved: int, found: bool) {
	combined := strings.builder_make()
	for path in paths {
		data, err := os.read_entire_file(path, context.allocator)
		if err != nil {
			continue
		}
		strings.write_string(&combined, path)
		strings.write_byte(&combined, 0)
		strings.write_bytes(&combined, data)
		if strings.has_suffix(path, "events.jsonl") {
			for line in strings.split(string(data), "\n") {
				if strings.trim_space(line) != "" {
					unresolved += 1
				}
			}
		}
	}
	if strings.builder_len(combined) == 0 {
		return "", 0, false
	}
	return hash_hex(strings.to_string(combined)), unresolved, true
}

op_import_validate :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Import_Validate_Params) or_return
	switch first_nonempty(p.kind, "legacy") {
	case "export":
		path, safe := workspace_file(ctx, p.path)
		if !safe {
			return {}, invalid("path must be a safe workspace-relative path")
		}
		data, read_err := os.read_entire_file(path, context.allocator)
		if read_err != nil {
			return {}, fail(.Not_Found, "import file does not exist")
		}
		doc: Export_Document
		if !decode(string(data), &doc) || doc.schema_version != SCHEMA_VERSION {
			return {}, invalid("export is not a compatible versioned document")
		}
		Data :: struct {
			kind:        string,
			source_hash: string,
			valid:       bool,
		}
		res.data = to_json(Data{"export", hash_hex(string(data)), true})
		return

	case "legacy":
		paths, safe := legacy_paths(ctx, p.path)
		if !safe {
			return {}, invalid("path must be a safe workspace-relative path")
		}
		source_hash, unresolved, found := legacy_source_hash(paths)
		if !found {
			return {}, fail(.Not_Found, "no legacy learning files were found")
		}
		Data :: struct {
			kind:                      string,
			source_hash:               string,
			unresolved_events:         int,
			originals_preserved:       bool,
			test_command_will_execute: bool,
		}
		res.data = to_json(Data{"legacy", source_hash, unresolved, true, false})
		append(
			&res.warnings,
			"legacy event ids remain unresolved unless an explicit provider/problem mapping is supplied; no mastery is inferred",
		)
		append(
			&res.next_actions,
			"review this preview, then call import_apply with the same source_hash",
		)
		return
	}
	return {}, invalid("kind must be legacy or export")
}

op_import_apply :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Import_Apply_Params) or_return
	switch p.kind {
	case "export":
		return import_export(ctx, store, p)
	case "legacy":
		return import_legacy(ctx, store, req, p)
	}
	return {}, invalid("kind must be legacy or export")
}

// import_export installs an exported event stream into an empty workspace, or
// confirms that the workspace already holds exactly that history. No merge is
// ever guessed.
@(private = "file")
import_export :: proc(
	ctx: ^Context,
	store: ^Store,
	p: Import_Apply_Params,
) -> (
	res: Result,
	err: Op_Error,
) {
	path, safe := workspace_file(ctx, p.path)
	if !safe {
		return {}, invalid("path must be a safe workspace-relative path")
	}
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		return {}, fail(.Not_Found, "export file does not exist")
	}
	if hash_hex(string(data)) != p.source_hash {
		return {}, fail(.Stale_Source, "export changed after validation; validate again")
	}
	doc: Export_Document
	if !decode(string(data), &doc) || doc.schema_version != SCHEMA_VERSION {
		return {}, invalid("export is not compatible")
	}
	if len(doc.events) == 0 {
		return {}, invalid("export contains no authoritative events")
	}
	for source in doc.sources {
		if !safe_relative_path(source.source_path) ||
		   hash_hex(source.content) != source.source_hash {
			return {}, invalid("export contains an unsafe or corrupt source entry")
		}
		destination := join(ctx.workspace, source.source_path)
		if existing_hash, hash_err := read_source_hash(destination);
		   hash_err == nil && existing_hash != source.source_hash {
			return {}, fail(.Destination_Exists, "an imported source path already contains different bytes")
		}
	}

	events := make([]Event, len(doc.events))
	log := strings.builder_make()
	for raw, i in doc.events {
		ev, ok := parse_event(string(raw))
		if !ok || ev.sequence != i + 1 {
			return {}, invalid("export event sequence is missing, corrupt, or non-contiguous")
		}
		events[i] = ev
		strings.write_string(&log, string(to_json(ev)))
		strings.write_byte(&log, '\n')
	}

	Data :: struct {
		replayed:             Replayed `json:",omitempty"`,
		imported_events:      int,
		workspace_revision:   Maybe(int) `json:",omitempty"`,
		source_code_included: Maybe(bool) `json:",omitempty"`,
	}
	if store.revision > 0 {
		if len(store.events) != len(events) {
			return {}, fail(.Request_Conflict, "destination has different history; import into an empty workspace or reconcile explicitly")
		}
		for ev, i in events {
			current := store.events[i]
			if current.event_id != ev.event_id ||
			   current.type != ev.type ||
			   current.payload != ev.payload {
				return {}, fail(.Request_Conflict, "destination contains a conflicting event; no merge was guessed")
			}
		}
		res.data = to_json(Data{replayed = true, imported_events = len(events)})
		return
	}

	if ensure_dirs(ctx.workspace) != nil ||
	   write_private_file(events_path(ctx.workspace), strings.to_string(log)) != nil {
		return {}, fail(.Storage_Error, "could not install the exported event stream")
	}
	load_err: Engine_Error
	store^, load_err = load_store(ctx.workspace)
	if load_err != nil {
		return {}, fail(.Storage_Error, "installed export failed event replay")
	}
	for source in doc.sources {
		destination := join(ctx.workspace, source.source_path)
		if !os.is_file(destination) && write_private_file(destination, source.content) != nil {
			return {}, fail(.Storage_Error, "events imported but a selected source file could not be restored")
		}
	}
	projection := fold(store)
	if write_state(ctx.workspace, &projection) != nil {
		return {}, fail(.Storage_Error, "imported events but could not write the projection")
	}
	manifest := Manifest {
		SCHEMA_VERSION,
		ENGINE_VERSION,
		store.workspace_id,
		now_rfc3339(),
		p.source_hash,
	}
	if write_private_file(manifest_path(ctx.workspace), string(to_json(manifest))) != nil {
		return {}, fail(.Storage_Error, "imported events but could not write the manifest")
	}
	res.data = to_json(
		Data {
			imported_events = len(events),
			workspace_revision = store.revision,
			source_code_included = len(doc.sources) > 0,
		},
	)
	return
}

// import_legacy records that a legacy source was reviewed. Nothing is
// inferred from it and its test command is never executed.
@(private = "file")
import_legacy :: proc(
	ctx: ^Context,
	store: ^Store,
	req: Request,
	p: Import_Apply_Params,
) -> (
	res: Result,
	err: Op_Error,
) {
	paths, safe := legacy_paths(ctx, p.path)
	if !safe {
		return {}, invalid("path must be a safe workspace-relative path")
	}
	actual_hash, unresolved, found := legacy_source_hash(paths)
	if !found {
		return {}, fail(.Not_Found, "legacy source is missing")
	}
	if actual_hash != p.source_hash {
		return {}, fail(.Stale_Source, "legacy files changed after validation; validate again")
	}

	Data :: struct {
		replayed:            Replayed `json:",omitempty"`,
		source_hash:         string,
		unresolved_events:   Maybe(int) `json:",omitempty"`,
		originals_preserved: Maybe(bool) `json:",omitempty"`,
	}
	for ev in store.events {
		prior: Legacy_Imported
		if is_event(ev, {.Legacy_Imported}) &&
		   decode(string(ev.payload), &prior) &&
		   prior.source_hash == actual_hash {
			res.data = to_json(Data{replayed = true, source_hash = actual_hash})
			append(&res.warnings, "this exact legacy source was already imported")
			return
		}
	}

	payload := Legacy_Imported{actual_hash, unresolved, false, false}
	_, replayed := commit(ctx, store, req, .Legacy_Imported, payload) or_return
	res = mutation_result(replayed)
	summary_path := learning_path(
		ctx.workspace,
		"imports",
		fmt.tprintf("legacy-%s.json", actual_hash[:16]),
	)
	if write_private_file(summary_path, string(to_json(payload))) != nil {
		append(
			&res.warnings,
			"import event was committed but its source summary file could not be written",
		)
	}
	res.data = to_json(Data{replayed_flag(replayed), actual_hash, unresolved, true})
	return
}

// -- data_delete ---------------------------------------------------------------

Data_Delete_Params :: struct {
	scope:           string, // session | export | all_learning
	session_id:      string,
	export_id:       string,
	execute:         bool,
	confirmation:    string,
	include_backups: bool,
}

// op_data_delete previews by default; executing requires confirmation text
// naming the exact scope. Solutions and provider credentials are never touched.
op_data_delete :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Data_Delete_Params) or_return
	target: string
	switch p.scope {
	case "session":
		if p.session_id == "" {
			return {}, invalid("session_id is required for session deletion")
		}
		st := fold(store)
		if find_session(&st, p.session_id) == nil {
			return {}, fail(.Not_Found, "session does not exist")
		}
		target = learning_path(ctx.workspace, "sessions", p.session_id)
	case "export":
		if !strings.has_prefix(p.export_id, "export_") {
			return {}, invalid("a valid export_id is required")
		}
		target = learning_path(
			ctx.workspace,
			"exports",
			strings.concatenate({p.export_id, ".json"}),
		)
	case "all_learning":
		target = learning_path(ctx.workspace)
	case:
		return {}, invalid("scope must be session, export, or all_learning")
	}

	Data :: struct {
		scope:                              string,
		target:                             string,
		will_preserve_solutions:            bool,
		will_preserve_provider_credentials: bool,
		preview:                            Maybe(bool) `json:",omitempty"`,
		deleted:                            Maybe(bool) `json:",omitempty"`,
	}
	data := Data {
		scope                              = p.scope,
		target                             = target,
		will_preserve_solutions            = true,
		will_preserve_provider_credentials = true,
	}
	confirmation := fmt.aprintf("DELETE %s", p.scope)
	if !p.execute {
		data.preview = true
		res.data = to_json(data)
		append(
			&res.next_actions,
			fmt.aprintf("repeat with execute=true and confirmation=%q", confirmation),
		)
		return
	}
	if p.confirmation != confirmation {
		return {}, invalid("confirmation does not match the exact deletion scope")
	}

	switch p.scope {
	case "all_learning":
		if os.remove_all(target) != nil {
			return {}, fail(.Storage_Error, "could not remove all plugin learning data")
		}
	case "export":
		if remove_err := os.remove(target); remove_err != nil && remove_err != .Not_Exist {
			return {}, fail(.Storage_Error, "could not remove the selected export")
		}
	case "session":
		delete_session(ctx, store, p.session_id, p.include_backups) or_return
		if !p.include_backups {
			append(
				&res.warnings,
				"existing plugin-managed backups were not included and may retain older copies",
			)
		}
	}
	data.deleted = true
	res.data = to_json(data)
	return
}

// delete_session redacts the session's event payloads in place, keeping
// content-free tombstones so sequence numbers and references stay intact.
@(private = "file")
delete_session :: proc(
	ctx: ^Context,
	store: ^Store,
	session_id: string,
	include_backups: bool,
) -> Op_Error {
	st := fold(store)
	log := strings.builder_make()
	for ev in store.events {
		redacted := ev
		if ev.session_id == session_id {
			redacted.actor = "system"
			redacted.type = EVENT_TYPE_NAMES[.Content_Redacted]
			redacted.attempt_id = ""
			redacted.payload = `{"redacted":true,"scope":"session"}`
		}
		strings.write_string(&log, string(to_json(redacted)))
		strings.write_byte(&log, '\n')
	}
	if write_private_file(events_path(ctx.workspace), strings.to_string(log)) != nil {
		return fail(.Storage_Error, "could not rewrite the redacted event stream")
	}
	for a in st.attempts {
		if a.session_id == session_id {
			os.remove_all(learning_path(ctx.workspace, "attempts", a.id))
		}
	}
	os.remove_all(learning_path(ctx.workspace, "sessions", session_id))
	if include_backups {
		os.remove_all(learning_path(ctx.workspace, "backups"))
	}

	load_err: Engine_Error
	store^, load_err = load_store(ctx.workspace)
	if load_err != nil {
		return fail(.Storage_Error, "session was redacted but state replay failed")
	}
	projection := fold(store)
	write_state(ctx.workspace, &projection)
	return nil
}
