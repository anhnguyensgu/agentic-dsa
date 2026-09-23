package learning

// Compact, evidence-backed session handoff for context loss and host changes
// (section 14). It deliberately excludes credentials and full conversations.

import "core:fmt"
import "core:encoding/json"
import "core:os"
import "core:strings"

session_attempt_index :: proc(st: ^State, session_id: string) -> int {
	index := -1
	for _, i in st.attempts { if st.attempts[i].session_id == session_id { index = i } }
	return index
}

pending_jobs_json :: proc(store: ^Store, session_id: string) -> [dynamic]string {
	ids := make([dynamic]string)
	for &ev in store.events {
		if ev.type != "submission_sent" || ev.session_id != session_id { continue }
		v, err := json.parse(ev.payload, .JSON, parse_integers = true)
		if err != nil { continue }
		id := jstr(jget(v, "job_id"))
		job := find_job(store, id)
		if job.found && job.state != "terminal" {
			o := obj_new()
			obj_field_str(&o, "job_id", job.id)
			obj_field_str(&o, "provider", job.provider)
			obj_field_str(&o, "remote_id", job.remote_id)
			obj_field_str(&o, "problem_key", job.problem_key)
			obj_field_str(&o, "source_hash", job.source_hash)
			obj_field_str(&o, "state", job.state)
			append(&ids, obj_done(&o))
			obj_free(&o)
		}
	}
	return ids
}

session_handoff_json :: proc(store: ^Store, session_id: string) -> (string, bool) {
	st := fold(store)
	si := state_session_index(&st, session_id)
	if si < 0 { return "", false }
	session := &st.sessions[si]
	o := obj_new()
	defer obj_free(&o)
	obj_field_int(&o, "schema_version", SCHEMA_VERSION)
	obj_field_str(&o, "engine_version", ENGINE_VERSION)
	obj_field_str(&o, "catalog_version", CATALOG_VERSION)
	obj_field_str(&o, "workspace_id", st.workspace_id)
	obj_field_int(&o, "workspace_revision", st.revision)
	obj_field_raw(&o, "profile", profile_to_json(&st.profile))
	obj_field_raw(&o, "session", session_to_json(session))
	ai := session_attempt_index(&st, session_id)
	if ai >= 0 {
		a := &st.attempts[ai]
		current_hash, _ := read_source_hash(join({store.workspace, a.source_path}))
		attempt_json := obj_new()
		obj_field_raw(&attempt_json, "record", attempt_to_json(a))
		obj_field_str(&attempt_json, "current_source_hash", current_hash)
		obj_field_bool(&attempt_json, "changed_since_creation", current_hash != "" && current_hash != a.source_hash)
		obj_field_raw(&o, "attempt", obj_done(&attempt_json))
		obj_free(&attempt_json)
	} else {
		obj_field_raw(&o, "attempt", "null")
	}
	hints := make([dynamic]string)
	defer delete(hints)
	results := make([dynamic]string)
	defer delete(results)
	for &ev in store.events {
		if ev.session_id != session_id { continue }
		if ev.type == "hint_delivered" { append(&hints, event_to_json(&ev)) }
		if ev.type == "runner_observed" || ev.type == "job_observed" || ev.type == "judge_observed" || ev.type == "assessment_recorded" {
			append(&results, event_to_json(&ev))
		}
	}
	obj_field_raws(&o, "hints", hints[:])
	obj_field_raws(&o, "results_and_assessments", results[:])
	jobs := pending_jobs_json(store, session_id)
	defer delete(jobs)
	obj_field_raws(&o, "pending_jobs", jobs[:])
	obj_field_str(&o, "next_action", session.next_action)
	return obj_done(&o), true
}

write_session_handoff :: proc(store: ^Store, session_id: string) -> Engine_Error {
	json_text, found := session_handoff_json(store, session_id)
	if !found { return .Not_Found }
	base := join({store.workspace, LEARNING_DIR, "sessions", session_id})
	if write_private_file(join({base, "handoff.json"}), json_text) != nil { return .Storage_Error }
	st := fold(store)
	si := state_session_index(&st, session_id)
	s := &st.sessions[si]
	markdown := strings.concatenate({
		"# Algorithm Learning handoff\n\n",
		"Session: `", s.id, "`\n\n",
		"Objective: ", s.objective, "\n\n",
		"Mode: `", s.mode, "`; activity: `", s.activity, "`; status: `", s.status, "`\n\n",
		"Learner summary: ", s.summary, "\n\n",
		"Next action: ", s.next_action, "\n\n",
		"Authoritative detail is in `handoff.json` at workspace revision ", fmt.aprintf("%d", st.revision), ".\n",
	}) or_else ""
	if write_private_file(join({base, "handoff.md"}), markdown) != nil { return .Storage_Error }
	return .None
}
