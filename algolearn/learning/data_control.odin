package learning

// Conservative import/export and exact-scope deletion (sections 10 and 15).
// Provider credentials, caches, and full statements are never exported.

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

workspace_file :: proc(ctx: ^Context, relative: string) -> (string, Engine_Error) {
	if !safe_relative_path(relative) { return "", .Invalid_Input }
	path := join({ctx.workspace, relative})
	if os.is_file(path) && !path_is_within_workspace(ctx.workspace, path) { return "", .Invalid_Input }
	return path, .None
}

op_export_create :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {}, {"scope", "session_id", "include_source"}); fail.status == .Error { return fail }
	scope := get_opt_str(input, "scope")
	if scope == "" { scope = "profile_history" }
	if scope != "profile_history" && scope != "handoff" { return bad_input("scope must be profile_history or handoff") }
	st := fold(store)
	export_id := fmt_id("export", store.revision + 1)
	doc := obj_new()
	defer obj_free(&doc)
	obj_field_int(&doc, "schema_version", SCHEMA_VERSION)
	obj_field_str(&doc, "export_version", "1")
	obj_field_str(&doc, "export_id", export_id)
	obj_field_str(&doc, "workspace_id", st.workspace_id)
	obj_field_int(&doc, "workspace_revision", st.revision)
	obj_field_str(&doc, "scope", scope)
	obj_field_strs(&doc, "excluded", {"provider_credentials", "provider_caches", "full_problem_statements"})
	if scope == "handoff" {
		session_id := get_opt_str(input, "session_id")
		if session_id == "" { return bad_input("session_id is required for a handoff export") }
		handoff, found := session_handoff_json(store, session_id)
		if !found { return error_result(.Not_Found, "session does not exist") }
		obj_field_raw(&doc, "handoff", handoff)
	} else {
		obj_field_raw(&doc, "profile", profile_to_json(&st.profile))
		sessions := make([dynamic]string)
		defer delete(sessions)
		for _, i in st.sessions { append(&sessions, session_to_json(&st.sessions[i])) }
		obj_field_raws(&doc, "sessions", sessions[:])
		concepts := make([dynamic]string)
		defer delete(concepts)
		for _, i in st.concepts { append(&concepts, concept_to_json(&st.concepts[i])) }
		obj_field_raws(&doc, "concepts", concepts[:])
		reviews := make([dynamic]string)
		defer delete(reviews)
		for _, i in st.reviews { append(&reviews, review_to_json(&st.reviews[i])) }
		obj_field_raws(&doc, "reviews", reviews[:])
		attempts := make([dynamic]string)
		defer delete(attempts)
		for _, i in st.attempts { append(&attempts, attempt_to_json(&st.attempts[i])) }
		obj_field_raws(&doc, "attempts", attempts[:])
		events := make([dynamic]string)
		defer delete(events)
		for &ev in store.events {
			// Remote authorization references and raw provider observations are
			// deliberately outside the default portable history.
			if ev.type == "submission_sent" || ev.type == "submission_outcome_unknown" ||
			   ev.type == "job_observed" || ev.type == "export_created" {
				redacted := ev
				redacted.actor = "system"
				redacted.type = "private_event_redacted"
				redacted.payload = `{"redacted":true,"reason":"private_remote_metadata"}`
				redacted.attempt_id = ""
				append(&events, event_to_json(&redacted))
			} else {
				append(&events, event_to_json(&ev))
			}
		}
		obj_field_raws(&doc, "events", events[:])
		if jbool(jget(input, "include_source")) {
			sources := make([dynamic]string)
			defer delete(sources)
			for a in st.attempts {
				bytes, err := os.read_entire_file(join({ctx.workspace, a.source_path}), context.allocator)
				if err != nil { continue }
				o := obj_new()
				obj_field_str(&o, "attempt_id", a.id)
				obj_field_str(&o, "source_path", a.source_path)
				obj_field_str(&o, "source_hash", hash_hex(string(bytes)))
				obj_field_str(&o, "content", string(bytes))
				append(&sources, obj_done(&o))
				obj_free(&o)
				delete(bytes)
			}
			obj_field_raws(&doc, "sources", sources[:])
		}
	}
	export_rel := join({LEARNING_DIR, "exports", fmt.aprintf("%s.json", export_id)})
	export_text := obj_done(&doc)
	if write_private_file(join({ctx.workspace, export_rel}), export_text) != nil { return error_result(.Storage_Error, "could not write the export") }
	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "export_id", export_id)
	obj_field_str(&p, "scope", scope)
	obj_field_str(&p, "path", export_rel)
	obj_field_str(&p, "content_hash", hash_hex(export_text))
	_, res := commit_and_project(store, ctx, req, "export_created", "", "", obj_done(&p))
	if res.status == .Error { return res }
	obj_field_str(&res.data, "export_id", export_id)
	obj_field_str(&res.data, "path", export_rel)
	obj_field_str(&res.data, "content_hash", hash_hex(export_text))
	obj_field_strs(&res.data, "excluded", {"provider_credentials", "provider_caches", "full_problem_statements"})
	return res
}

legacy_paths :: proc(ctx: ^Context, requested: string) -> ([]string, Engine_Error) {
	paths := make([dynamic]string)
	if requested != "" {
		path, err := workspace_file(ctx, requested)
		if err != .None { delete(paths); return nil, err }
		append(&paths, path)
		return paths[:], .None
	}
	append(&paths, join({ctx.workspace, ".algo", "config.json"}))
	append(&paths, join({ctx.workspace, ".algo", "events.jsonl"}))
	return paths[:], .None
}

legacy_source_hash :: proc(paths: []string) -> (string, int, Engine_Error) {
	combined := make([dynamic]u8)
	defer delete(combined)
	unresolved := 0
	for path in paths {
		bytes, err := os.read_entire_file(path, context.allocator)
		if err != nil { continue }
		append(&combined, path)
		append(&combined, 0)
		append(&combined, ..bytes)
		if strings.has_suffix(path, "events.jsonl") {
			for line in strings.split(string(bytes), "\n") { if strings.trim_space(line) != "" { unresolved += 1 } }
		}
		delete(bytes)
	}
	if len(combined) == 0 { return "", 0, .Not_Found }
	return hash_hex(string(combined[:])), unresolved, .None
}

op_import_validate :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {}, {"kind", "path", "mappings"}); fail.status == .Error { return fail }
	kind := get_opt_str(input, "kind")
	if kind == "" { kind = "legacy" }
	if kind != "legacy" && kind != "export" { return bad_input("kind must be legacy or export") }
	if kind == "export" {
		path, perr := workspace_file(ctx, get_opt_str(input, "path"))
		if perr != .None { return bad_input("path must be a safe workspace-relative path") }
		bytes, err := os.read_entire_file(path, context.allocator)
		if err != nil { return error_result(.Not_Found, "import file does not exist") }
		defer delete(bytes)
		doc, jerr := json.parse(bytes, .JSON, parse_integers = true)
		if jerr != nil || jint(jget(doc, "schema_version")) != SCHEMA_VERSION { return bad_input("export is not a compatible versioned document") }
		res := ok_result()
		obj_field_str(&res.data, "kind", kind)
		obj_field_str(&res.data, "source_hash", hash_hex(string(bytes)))
		obj_field_bool(&res.data, "valid", true)
		return res
	}
	paths, perr := legacy_paths(ctx, get_opt_str(input, "path"))
	if perr != .None { return bad_input("path must be a safe workspace-relative path") }
	defer delete(paths)
	source_hash, unresolved, herr := legacy_source_hash(paths)
	if herr != .None { return error_result(.Not_Found, "no legacy learning files were found") }
	res := ok_result()
	obj_field_str(&res.data, "kind", "legacy")
	obj_field_str(&res.data, "source_hash", source_hash)
	obj_field_int(&res.data, "unresolved_events", unresolved)
	obj_field_bool(&res.data, "originals_preserved", true)
	obj_field_bool(&res.data, "test_command_will_execute", false)
	append(&res.warnings, "legacy event ids remain unresolved unless an explicit provider/problem mapping is supplied; no mastery is inferred")
	append(&res.next_actions, "review this preview, then call import_apply with the same source_hash")
	return res
}

op_import_apply :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"kind", "source_hash"}, {"path", "mappings"}); fail.status == .Error { return fail }
	if jstr(jget(input, "kind")) == "export" {
		path, perr := workspace_file(ctx, get_opt_str(input, "path"))
		if perr != .None { return bad_input("path must be a safe workspace-relative path") }
		bytes, read_err := os.read_entire_file(path, context.allocator)
		if read_err != nil { return error_result(.Not_Found, "export file does not exist") }
		defer delete(bytes)
		if hash_hex(string(bytes)) != jstr(jget(input, "source_hash")) { return error_result(.Stale_Source, "export changed after validation; validate again") }
		doc, parse_err := json.parse(bytes, .JSON, parse_integers = true)
		if parse_err != nil || jint(jget(doc, "schema_version")) != SCHEMA_VERSION { return bad_input("export is not compatible") }
		exported := jarray(jget(doc, "events"))
		if len(exported) == 0 { return bad_input("export contains no authoritative events") }
		for source in jarray(jget(doc, "sources")) {
			relative := jstr(jget(source, "source_path"))
			content := jstr(jget(source, "content"))
			if !safe_relative_path(relative) || hash_hex(content) != jstr(jget(source, "source_hash")) {
				return bad_input("export contains an unsafe or corrupt source entry")
			}
			destination := join({ctx.workspace, relative})
			if os.is_file(destination) {
				existing_hash, _ := read_source_hash(destination)
				if existing_hash != jstr(jget(source, "source_hash")) { return error_result(.Destination_Exists, "an imported source path already contains different bytes") }
			}
		}
		lines := make([dynamic]u8)
		defer delete(lines)
		parsed_events := make([dynamic]Event)
		defer delete(parsed_events)
		expected_sequence := 1
		for value in exported {
			encoded, marshal_err := json.marshal(value)
			if marshal_err != nil { return bad_input("export contains an invalid event") }
			ev, ok := parse_event(string(encoded))
			delete(encoded)
			if !ok || ev.sequence != expected_sequence { return bad_input("export event sequence is missing, corrupt, or non-contiguous") }
			expected_sequence += 1
			append(&parsed_events, ev)
			append(&lines, event_to_json(&ev))
			append(&lines, '\n')
		}
		if store.revision > 0 {
			if len(store.events) != len(parsed_events) { return error_result(.Request_Conflict, "destination has different history; import into an empty workspace or reconcile explicitly") }
			for ev, i in parsed_events {
				current := store.events[i]
				if current.event_id != ev.event_id || current.type != ev.type || current.payload != ev.payload {
					return error_result(.Request_Conflict, "destination contains a conflicting event; no merge was guessed")
				}
			}
			res := ok_result()
			obj_field_bool(&res.data, "replayed", true)
			obj_field_int(&res.data, "imported_events", len(parsed_events))
			return res
		}
		if ensure_dirs(ctx.workspace) != nil || write_private_file(events_path(ctx.workspace), string(lines[:])) != nil {
			return error_result(.Storage_Error, "could not install the exported event stream")
		}
		updated, load_err := load_store(ctx.workspace)
		if load_err != .None { return error_result(.Storage_Error, "installed export failed event replay") }
		store^ = updated
		for source in jarray(jget(doc, "sources")) {
			destination := join({ctx.workspace, jstr(jget(source, "source_path"))})
			if !os.is_file(destination) && write_private_file(destination, jstr(jget(source, "content"))) != nil {
				return error_result(.Storage_Error, "events imported but a selected source file could not be restored")
			}
		}
		projection := fold(store)
		if write_state(ctx.workspace, &projection) != .None { return error_result(.Storage_Error, "imported events but could not write the projection") }
		manifest := obj_new()
		defer obj_free(&manifest)
		obj_field_int(&manifest, "schema_version", SCHEMA_VERSION)
		obj_field_str(&manifest, "engine_version", ENGINE_VERSION)
		obj_field_str(&manifest, "workspace_id", store.workspace_id)
		obj_field_str(&manifest, "created", now_rfc3339())
		obj_field_str(&manifest, "import_source_hash", jstr(jget(input, "source_hash")))
		if write_private_file(manifest_path(ctx.workspace), obj_done(&manifest)) != nil { return error_result(.Storage_Error, "imported events but could not write the manifest") }
		res := ok_result()
		obj_field_int(&res.data, "imported_events", len(parsed_events))
		obj_field_int(&res.data, "workspace_revision", store.revision)
		obj_field_bool(&res.data, "source_code_included", len(jarray(jget(doc, "sources"))) > 0)
		return res
	}
	if jstr(jget(input, "kind")) != "legacy" { return bad_input("kind must be legacy or export") }
	paths, perr := legacy_paths(ctx, get_opt_str(input, "path"))
	if perr != .None { return bad_input("path must be a safe workspace-relative path") }
	defer delete(paths)
	actual_hash, unresolved, herr := legacy_source_hash(paths)
	if herr != .None { return error_result(.Not_Found, "legacy source is missing") }
	if actual_hash != jstr(jget(input, "source_hash")) { return error_result(.Stale_Source, "legacy files changed after validation; validate again") }
	for ev in store.events {
		if ev.type != "legacy_imported" { continue }
		payload, err := json.parse(ev.payload, .JSON, parse_integers = true)
		if err == nil && jstr(jget(payload, "source_hash")) == actual_hash {
			res := ok_result()
			obj_field_bool(&res.data, "replayed", true)
			obj_field_str(&res.data, "source_hash", actual_hash)
			append(&res.warnings, "this exact legacy source was already imported")
			return res
		}
	}
	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "source_hash", actual_hash)
	obj_field_int(&p, "unresolved_events", unresolved)
	obj_field_bool(&p, "mastery_inferred", false)
	obj_field_bool(&p, "legacy_test_command_executed", false)
	_, res := commit_and_project(store, ctx, req, "legacy_imported", "", "", obj_done(&p))
	if res.status == .Error { return res }
	import_rel := join({LEARNING_DIR, "imports", fmt.aprintf("legacy-%s.json", actual_hash[:16])})
	if write_private_file(join({ctx.workspace, import_rel}), obj_done(&p)) != nil { append(&res.warnings, "import event was committed but its source summary file could not be written") }
	obj_field_str(&res.data, "source_hash", actual_hash)
	obj_field_int(&res.data, "unresolved_events", unresolved)
	obj_field_bool(&res.data, "originals_preserved", true)
	return res
}

op_data_delete :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"scope"}, {"session_id", "export_id", "execute", "confirmation", "include_backups"}); fail.status == .Error { return fail }
	scope := jstr(jget(input, "scope"))
	if scope != "session" && scope != "export" && scope != "all_learning" { return bad_input("scope must be session, export, or all_learning") }
	target := learning_dir(ctx.workspace)
	if scope == "session" {
		session_id := get_opt_str(input, "session_id")
		if session_id == "" { return bad_input("session_id is required for session deletion") }
		current_state := fold(store)
		if state_session_index(&current_state, session_id) < 0 { return error_result(.Not_Found, "session does not exist") }
		target = join({ctx.workspace, LEARNING_DIR, "sessions", session_id})
	} else if scope == "export" {
		export_id := get_opt_str(input, "export_id")
		if export_id == "" || !strings.has_prefix(export_id, "export_") { return bad_input("a valid export_id is required") }
		target = join({ctx.workspace, LEARNING_DIR, "exports", fmt.aprintf("%s.json", export_id)})
	}
	res := ok_result()
	obj_field_str(&res.data, "scope", scope)
	obj_field_str(&res.data, "target", target)
	obj_field_bool(&res.data, "will_preserve_solutions", true)
	obj_field_bool(&res.data, "will_preserve_provider_credentials", true)
	if !jbool(jget(input, "execute")) {
		obj_field_bool(&res.data, "preview", true)
		append(&res.next_actions, fmt.aprintf("repeat with execute=true and confirmation=%q", fmt.aprintf("DELETE %s", scope)))
		return res
	}
	if get_opt_str(input, "confirmation") != fmt.aprintf("DELETE %s", scope) { return bad_input("confirmation does not match the exact deletion scope") }
	if scope == "all_learning" {
		if err := os.remove_all(target); err != nil { return error_result(.Storage_Error, "could not remove all plugin learning data") }
		obj_field_bool(&res.data, "deleted", true)
		return res
	}
	if scope == "export" {
		if err := os.remove(target); err != nil && err != .Not_Exist { return error_result(.Storage_Error, "could not remove the selected export") }
		obj_field_bool(&res.data, "deleted", true)
		return res
	}
	// Session deletion redacts event payloads in place while retaining
	// content-free sequence tombstones for referential integrity.
	session_id := get_opt_str(input, "session_id")
	st := fold(store)
	content := make([dynamic]u8)
	defer delete(content)
	for ev in store.events {
		redacted := ev
		if ev.session_id == session_id {
			redacted.actor = "system"
			redacted.type = "content_redacted"
			redacted.attempt_id = ""
			redacted.payload = `{"redacted":true,"scope":"session"}`
		}
		append(&content, event_to_json(&redacted))
		append(&content, '\n')
	}
	if write_private_file(events_path(ctx.workspace), string(content[:])) != nil { return error_result(.Storage_Error, "could not rewrite the redacted event stream") }
	for attempt in st.attempts {
		if attempt.session_id == session_id { os.remove_all(join({ctx.workspace, LEARNING_DIR, "attempts", attempt.id})) }
	}
	os.remove_all(join({ctx.workspace, LEARNING_DIR, "sessions", session_id}))
	if jbool(jget(input, "include_backups")) { os.remove_all(join({ctx.workspace, LEARNING_DIR, "backups"})) }
	updated, load_err := load_store(ctx.workspace)
	if load_err != .None { return error_result(.Storage_Error, "session was redacted but state replay failed") }
	store^ = updated
	projection := fold(store)
	_ = write_state(ctx.workspace, &projection)
	obj_field_bool(&res.data, "deleted", true)
	if !jbool(jget(input, "include_backups")) { append(&res.warnings, "existing plugin-managed backups were not included and may retain older copies") }
	return res
}
