package learning

// Domain model, stable error codes, and the response envelope (sections 10-11
// of AGENTIC_LEARNING.md). This file owns no I/O.

import "core:fmt"
import "core:time"

SCHEMA_VERSION :: 1
ENGINE_VERSION :: "0.2.0"

// Workspace layout (section 10): everything lives under the legacy .algo
// directory but in a separate learning/ subtree so existing files stay put.
LEARNING_DIR :: ".algo/learning"
EVENTS_FILE :: "events.jsonl"
STATE_FILE :: "state.json"
MANIFEST_FILE :: "manifest.json"
LOCK_DIR :: ".lock"

// Engine_Error carries a stable string code into the envelope. Domain
// outcomes such as "wrong answer" are data, not errors; these are for
// transport/validation/operational problems.
Engine_Error :: enum {
	None,
	Invalid_Input,
	Invalid_Evidence,
	Request_Conflict,
	Stale_Revision,
	Destination_Exists,
	Not_Found,
	Workspace_Locked,
	Storage_Error,
	Unsupported_Capability,
	Auth_Required,
	Rate_Limited,
	Offline_Cache_Miss,
	Stale_Source,
	Provider_Contract_Changed,
	Submission_Outcome_Unknown,
}

error_code :: proc(e: Engine_Error) -> string {
	#partial switch e {
	case .None:                    return ""
	case .Invalid_Input:           return "invalid_input"
	case .Invalid_Evidence:        return "invalid_evidence"
	case .Request_Conflict:        return "request_conflict"
	case .Stale_Revision:          return "stale_revision"
	case .Destination_Exists:      return "destination_exists"
	case .Not_Found:               return "not_found"
	case .Workspace_Locked:        return "workspace_locked"
	case .Storage_Error:           return "storage_error"
	case .Unsupported_Capability:  return "unsupported_capability"
	case .Auth_Required:           return "auth_required"
	case .Rate_Limited:            return "rate_limited"
	case .Offline_Cache_Miss:      return "offline_cache_miss"
	case .Stale_Source:            return "stale_source"
	case .Provider_Contract_Changed: return "provider_contract_changed"
	case .Submission_Outcome_Unknown: return "submission_outcome_unknown"
	}
	return "internal"
}

// CLI exit codes (section 11): 0 completed without a negative/unverified
// execution outcome, 1 operational failure, 2 invalid input, 3 failed
// solution, 4 unverified local result, 5 pending operation.
exit_code_for :: proc(e: Engine_Error) -> int {
	#partial switch e {
	case .None: return 0
	case .Invalid_Input, .Invalid_Evidence, .Request_Conflict, .Stale_Revision,
	     .Destination_Exists: return 2
	case .Not_Found, .Workspace_Locked, .Storage_Error, .Unsupported_Capability,
	     .Auth_Required, .Rate_Limited, .Offline_Cache_Miss, .Stale_Source,
	     .Provider_Contract_Changed, .Submission_Outcome_Unknown: return 1
	}
	return 1
}

// -- response envelope ---------------------------------------------------------

Status :: enum u8 {
	Completed,
	Pending,
	Error,
}

status_string :: proc(s: Status) -> string {
	#partial switch s {
	case .Completed: return "completed"
	case .Pending:   return "pending"
	case .Error:     return "error"
	}
	return "error"
}

// Result is what every operation handler returns; the CLI and MCP frontends
// wrap it in the same envelope (section 11).
Result :: struct {
	status:       Status,
	data:         Obj, // finished JSON object body
	warnings:     [dynamic]string,
	next_actions: [dynamic]string,
	err:          Engine_Error,
	message:      string,
	cli_exit:     int,
}

// -- request identity ----------------------------------------------------------

// Every mutating operation carries a unique request id and the workspace
// revision it loaded (section 10). expected_revision < 0 means "latest known".
Request :: struct {
	request_id:        string,
	request_hash:      string,
	expected_revision: int,
}

// -- event record (section 10) ---------------------------------------------

Event :: struct {
	sequence:     int,
	event_id:     string,
	workspace_id: string,
	timestamp:    string, // RFC3339 UTC, fixed width, lexicographic == chronological
	actor:        string, // "agent:<host>" | "learner" | "tool"
	type:         string,
	request_id:   string,
	request_hash: string, // hash of the full request payload
	session_id:   string,
	attempt_id:   string,
	payload:      string, // raw JSON object body
}

event_to_json :: proc(ev: ^Event) -> string {
	o := obj_new()
	defer obj_free(&o)
	obj_field_int(&o, "schema_version", SCHEMA_VERSION)
	obj_field_str(&o, "event_id", ev.event_id)
	obj_field_int(&o, "sequence", ev.sequence)
	obj_field_str(&o, "workspace_id", ev.workspace_id)
	obj_field_str(&o, "timestamp", ev.timestamp)
	obj_field_str(&o, "actor", ev.actor)
	obj_field_str(&o, "type", ev.type)
	obj_field_str(&o, "request_id", ev.request_id)
	obj_field_str(&o, "request_hash", ev.request_hash)
	obj_field_str(&o, "session_id", ev.session_id)
	obj_field_str(&o, "attempt_id", ev.attempt_id)
	obj_field_raw(&o, "payload", ev.payload)
	return obj_done(&o)
}

rfc3339_utc :: proc(t: time.Time) -> string {
	// Fixed-width UTC stamps: "2026-09-19T15:00:00Z". Lexicographic order
	// matches chronological order, so due-date comparisons are string compares.
	s, ok := time.time_to_rfc3339(t, 0, false)
	return s if ok else ""
}

now_rfc3339 :: proc() -> string {
	return rfc3339_utc(time.now())
}

fmt_id :: proc(prefix: string, seq: int) -> string {
	return fmt.aprintf("%s_%06d", prefix, seq)
}
