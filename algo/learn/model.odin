// Package learn holds the stateless algorithm-practice tools: attempt
// scaffolds, bounded local test runs, and judge submissions. It stores no
// learner state. Each operation returns the events it produced, and the host
// agent keeps them in its own memory (schemas/event-v2.json).
//
// Every operation runs inside one arena owned by its caller; nothing in this
// package frees individual allocations.
package learn

import "../safeio"
import "core:crypto"
import "core:crypto/sha2"
import "core:encoding/hex"
import "core:fmt"
import "core:os"
import "core:time"

SCHEMA_VERSION :: 2
ENGINE_VERSION :: "0.5.0"

// Engine_Error is a transport, validation, or operational failure. Domain
// outcomes such as a wrong answer are data, not errors.
Engine_Error :: enum {
	None,
	Invalid_Input,
	Destination_Exists,
	Not_Found,
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
	.Destination_Exists         = "destination_exists",
	.Not_Found                  = "not_found",
	.Storage_Error              = "storage_error",
	.Unsupported_Capability     = "unsupported_capability",
	.Auth_Required              = "auth_required",
	.Rate_Limited               = "rate_limited",
	.Offline_Cache_Miss         = "offline_cache_miss",
	.Stale_Source               = "stale_source",
	.Provider_Contract_Changed  = "provider_contract_changed",
	.Submission_Outcome_Unknown = "submission_outcome_unknown",
}

// CLI exit codes: 0 completed without a negative or unverified execution
// outcome, 1 operational failure, 2 invalid input, 3 failed solution, 4
// unverified local result, 5 pending operation.
EXIT_INVALID_INPUT :: 2
EXIT_FAILED_SOLUTION :: 3
EXIT_UNVERIFIED :: 4
EXIT_PENDING :: 5

exit_code_for :: proc(e: Engine_Error) -> int {
	#partial switch e {
	case .None:
		return 0
	case .Invalid_Input, .Destination_Exists:
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
// in the same envelope.
Result :: struct {
	status:       Status,
	data:         Raw_JSON, // an encoded JSON object
	events:       [dynamic]Event, // for the host agent to keep; never stored here
	warnings:     [dynamic]string,
	next_actions: [dynamic]string,
	err:          Engine_Error,
	message:      string,
	cli_exit:     int,
}

// Request carries the caller's correlation id, echoed in the envelope.
Request :: struct {
	request_id: string,
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
// chronological order.
rfc3339_utc :: proc(t: time.Time) -> string {
	s, ok := time.time_to_rfc3339(t, 0, false)
	return s if ok else ""
}

// new_id mints a random id. Nothing is stored, so ids cannot come from a
// sequence; 64 random bits keep ids from different hosts apart.
new_id :: proc(prefix: string) -> string {
	bytes: [8]byte
	crypto.rand_bytes(bytes[:])
	return fmt.aprintf("%s_%s", prefix, string(hex.encode(bytes[:])))
}

join :: proc(parts: ..string) -> string {
	return os.join_path(parts, context.allocator) or_else ""
}

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

first_nonzero :: proc(values: ..int) -> int {
	for v in values {
		if v != 0 {
			return v
		}
	}
	return 0
}

first_nonempty :: proc(values: ..string) -> string {
	for v in values {
		if v != "" {
			return v
		}
	}
	return ""
}
