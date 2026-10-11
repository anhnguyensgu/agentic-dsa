// Package learning is the Algorithm Learning engine: an append-only event log
// per workspace, a projection folded from it, and the operation handlers the
// CLI and MCP frontends share (AGENTIC_LEARNING.md sections 5-15).
//
// Every operation runs inside one arena owned by its caller; nothing in this
// package frees individual allocations.
package learning

import "core:fmt"
import "core:time"

SCHEMA_VERSION :: 1
ENGINE_VERSION :: "0.2.0"

// Workspace layout (section 10): the learning subtree sits beside, and never
// modifies, the legacy .algo files.
LEARNING_DIR :: ".algo/learning"
EVENTS_FILE :: "events.jsonl"
STATE_FILE :: "state.json"
MANIFEST_FILE :: "manifest.json"
LOCK_DIR :: ".lock"

// Engine_Error is a transport, validation, or operational failure. Domain
// outcomes such as a wrong answer are data, not errors.
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

// Stable codes carried in the response envelope.
ERROR_CODES := [Engine_Error]string {
	.None                       = "",
	.Invalid_Input              = "invalid_input",
	.Invalid_Evidence           = "invalid_evidence",
	.Request_Conflict           = "request_conflict",
	.Stale_Revision             = "stale_revision",
	.Destination_Exists         = "destination_exists",
	.Not_Found                  = "not_found",
	.Workspace_Locked           = "workspace_locked",
	.Storage_Error              = "storage_error",
	.Unsupported_Capability     = "unsupported_capability",
	.Auth_Required              = "auth_required",
	.Rate_Limited               = "rate_limited",
	.Offline_Cache_Miss         = "offline_cache_miss",
	.Stale_Source               = "stale_source",
	.Provider_Contract_Changed  = "provider_contract_changed",
	.Submission_Outcome_Unknown = "submission_outcome_unknown",
}

// CLI exit codes (section 11): 0 completed without a negative or unverified
// execution outcome, 1 operational failure, 2 invalid input, 3 failed
// solution, 4 unverified local result, 5 pending operation.
EXIT_INVALID_INPUT :: 2
EXIT_FAILED_SOLUTION :: 3
EXIT_UNVERIFIED :: 4
EXIT_PENDING :: 5

exit_code_for :: proc(e: Engine_Error) -> int {
	#partial switch e {
	case .None:
		return 0
	case .Invalid_Input, .Invalid_Evidence, .Request_Conflict, .Stale_Revision, .Destination_Exists:
		return EXIT_INVALID_INPUT
	}
	return 1
}

Status :: enum u8 {
	Completed,
	Pending,
	Error,
}

STATUS_NAMES := [Status]string {
	.Completed = "completed",
	.Pending   = "pending",
	.Error     = "error",
}

// Result is what every operation produces; the CLI and MCP frontends wrap it
// in the same envelope (section 11).
Result :: struct {
	status:       Status,
	data:         Raw_JSON, // an encoded JSON object
	warnings:     [dynamic]string,
	next_actions: [dynamic]string,
	err:          Engine_Error,
	message:      string,
	cli_exit:     int,
}

// Every mutating operation carries a unique request id and the workspace
// revision it loaded (section 10). expected_revision < 0 means "latest".
Request :: struct {
	request_id:        string,
	request_hash:      string,
	expected_revision: int,
}

// Context identifies the caller. A zero now means the real clock; tests pin it.
Context :: struct {
	workspace: string,
	actor:     string, // "agent:<host>" | "learner" | "tool"
	host:      string,
	now:       time.Time,
}

context_now :: proc(ctx: ^Context) -> time.Time {
	return ctx.now if ctx.now != {} else time.now()
}

// Fixed-width UTC stamps ("2026-09-19T15:00:00Z") sort lexicographically in
// chronological order, so due dates compare as strings.
rfc3339_utc :: proc(t: time.Time) -> string {
	s, ok := time.time_to_rfc3339(t, 0, false)
	return s if ok else ""
}

now_rfc3339 :: proc() -> string {
	return rfc3339_utc(time.now())
}

// Ids are minted from the sequence number of the event that creates them.
fmt_id :: proc(prefix: string, sequence: int) -> string {
	return fmt.aprintf("%s_%06d", prefix, sequence)
}
