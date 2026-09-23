package learning

// Deterministic domain and storage tests (section 18, test layers):
// state transitions, identity, validation, and event replay with a frozen
// clock and temporary workspaces.

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:testing"
import "core:time"

// -- frozen clock ----------------------------------------------------------------

fake_now :: proc "contextless" () -> time.Time {
	return time.unix(1758300000, 0)
}

freeze_clock :: proc(t: ^testing.T) {
}

unfreeze_clock :: proc() {
}

with_arena :: proc(t: ^testing.T) -> mem.Dynamic_Arena {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)
	return arena
}

temp_workspace :: proc(t: ^testing.T) -> string {
	dir, err := os.make_directory_temp("", "algolearn-test-*", context.allocator)
	if !testing.expect(t, err == nil) {
		return ""
	}
	return dir
}

// -- schedule tests ----------------------------------------------------------------

@(test)
schedule_independent_successes_advance_and_cap :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)

	// New item: first independent success schedules the 3-day interval.
	ni, days := next_interval(0, .Independent_Correct)
	testing.expect_value(t, ni, 1)
	testing.expect_value(t, days, 3)

	ni, days = next_interval(ni, .Independent_Correct)
	testing.expect_value(t, ni, 2)
	testing.expect_value(t, days, 7)

	ni, days = next_interval(ni, .Independent_Correct)
	testing.expect_value(t, ni, 3)
	testing.expect_value(t, days, 21)

	// 60 days, then capped at 60 forever.
	ni, days = next_interval(ni, .Independent_Correct)
	testing.expect_value(t, ni, 3)
	testing.expect_value(t, days, 60)
	ni, days = next_interval(ni, .Independent_Correct)
	testing.expect_value(t, days, 60)
}

@(test)
schedule_help_lapse_and_neutral_outcomes :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)

	// Correct after meaningful help resets to the initial 1-day interval.
	ni, days := next_interval(2, .Correct_After_Help)
	testing.expect_value(t, ni, 0)
	testing.expect_value(t, days, INITIAL_INTERVAL_DAYS)

	// A conceptual lapse also resets.
	ni, days = next_interval(3, .Incorrect_Recall)
	testing.expect_value(t, ni, 0)
	testing.expect_value(t, days, INITIAL_INTERVAL_DAYS)

	// Tool failure and skip leave progress unchanged.
	ni, days = next_interval(2, .Tool_Failure)
	testing.expect_value(t, ni, 2)
	testing.expect_value(t, days, 0)
	ni, days = next_interval(2, .Skipped)
	testing.expect_value(t, ni, 2)
	testing.expect_value(t, days, 0)
}

@(test)
schedule_due_dates_use_completion_time :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)
	freeze_clock(t)
	defer unfreeze_clock()

	ni, due := apply_outcome(0, "2025-01-01T00:00:00Z", .Independent_Correct, fake_now())
	testing.expect_value(t, ni, 1)
	testing.expect_value(t, due, "2025-09-22T16:40:00Z") // 3 days after the frozen now

	_, due = apply_outcome(0, "2025-01-01T00:00:00Z", .Incorrect_Recall, fake_now())
	testing.expect_value(t, due, "2025-09-20T16:40:00Z") // 1 day after the frozen now

	// Tool failure preserves the previous due date.
	_, due = apply_outcome(0, "2025-01-01T00:00:00Z", .Tool_Failure, fake_now())
	testing.expect_value(t, due, "2025-01-01T00:00:00Z")
}

// -- store tests --------------------------------------------------------------------

@(test)
store_round_trip_dedup_and_revision :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)
	freeze_clock(t)
	defer unfreeze_clock()
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	store, err := load_store(ws)
	testing.expect_value(t, err, Engine_Error.None)
	testing.expect_value(t, store.revision, 0)

	// First commit into an empty workspace: revision 0 is expected.
	req := Request{request_id = "r1", request_hash = "h1", expected_revision = 0}
	ev, cerr, replayed := commit_event(&store, "session_started", "agent:test", req, "s1", "", `{"objective":"o"}`)
	testing.expect_value(t, cerr, Engine_Error.None)
	testing.expect(t, !replayed)
	testing.expect_value(t, ev.sequence, 1)
	testing.expect(t, strings.has_prefix(ev.event_id, "ev_"))
	testing.expect(t, strings.has_suffix(ev.event_id, "_000001"))
	testing.expect(t, strings.has_prefix(ev.workspace_id, "ws_"))

	// Reloading from disk restores the same revision and event.
	reloaded, lerr := load_store(ws)
	testing.expect_value(t, lerr, Engine_Error.None)
	testing.expect_value(t, reloaded.revision, 1)
	testing.expect_value(t, len(reloaded.events), 1)
	testing.expect_value(t, reloaded.events[0].event_id, ev.event_id)
	testing.expect_value(t, reloaded.events[0].payload, `{"objective":"o"}`)

	// Repeating an identical request returns the existing event.
	req_again := Request{request_id = "r1", request_hash = "h1", expected_revision = 1}
	ev2, cerr2, replayed2 := commit_event(&reloaded, "session_started", "agent:test", req_again, "s1", "", `{"objective":"o"}`)
	testing.expect_value(t, cerr2, Engine_Error.None)
	testing.expect(t, replayed2)
	testing.expect_value(t, ev2.event_id, ev.event_id)

	// Reusing the id with a different payload conflicts.
	req_conflict := Request{request_id = "r1", request_hash = "h2", expected_revision = 1}
	_, cerr3, _ := commit_event(&reloaded, "session_started", "agent:test", req_conflict, "s1", "", `{"objective":"changed"}`)
	testing.expect_value(t, cerr3, Engine_Error.Request_Conflict)

	// A stale revision conflicts.
	req_stale := Request{request_id = "r2", request_hash = "h3", expected_revision = 0}
	_, cerr4, _ := commit_event(&reloaded, "hint_delivered", "agent:test", req_stale, "s1", "", `{}`)
	testing.expect_value(t, cerr4, Engine_Error.Stale_Revision)

	// Unversioned callers (expected_revision < 0) accept the latest revision.
	req_latest := Request{request_id = "r3", request_hash = "h4", expected_revision = -1}
	_, cerr5, _ := commit_event(&reloaded, "hint_delivered", "agent:test", req_latest, "s1", "", `{}`)
	testing.expect_value(t, cerr5, Engine_Error.None)

	after, lerr2 := load_store(ws)
	testing.expect_value(t, lerr2, Engine_Error.None)
	testing.expect_value(t, after.revision, 2)
}

@(test)
store_preserves_truncated_tail_and_blocks_writes :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)
	freeze_clock(t)
	defer unfreeze_clock()
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	// Two valid records plus a truncated final record.
	// Odin's fmt treats braces in format strings as directives, so the raw
	// record is assembled by concatenation instead of aprintf.
	valid := "{\"schema_version\":1,\"event_id\":\"ev_000001\",\"sequence\":1,\"workspace_id\":\"ws_x\",\"timestamp\":\"2025-09-19T15:20:00Z\",\"actor\":\"agent:test\",\"type\":\"session_started\",\"request_id\":\"\",\"request_hash\":\"\",\"session_id\":\"s1\",\"attempt_id\":\"\",\"payload\":{}}\n"
	truncated := "{\"event_id\":\"ev_000002\",\"sequence\":2,\"truncat"
	testing.expect_value(t,
		write_private_file(events_path(ws), strings.concatenate({valid, truncated})),
		nil)

	store, err := load_store(ws)
	testing.expect_value(t, err, Engine_Error.None)
	testing.expect_value(t, store.revision, 1)
	testing.expect(t, store.tail_warning != "")

	// Writes are refused so the damaged tail is never silently dropped.
	req := Request{request_id = "r1", request_hash = "h1", expected_revision = 1}
	_, cerr, _ := commit_event(&store, "hint_delivered", "agent:test", req, "s1", "", `{}`)
	testing.expect_value(t, cerr, Engine_Error.Storage_Error)

	// The original bytes are untouched.
	data, _ := os.read_entire_file(events_path(ws), context.allocator)
	defer delete(data)
	testing.expect(t, strings.has_suffix(string(data), "\"truncat"))
}

@(test)
store_middle_corruption_is_an_error :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	valid := "{\"schema_version\":1,\"event_id\":\"ev_000001\",\"sequence\":1,\"workspace_id\":\"ws_x\",\"timestamp\":\"2025-09-19T15:20:00Z\",\"actor\":\"agent:test\",\"type\":\"session_started\",\"request_id\":\"\",\"request_hash\":\"\",\"session_id\":\"s1\",\"attempt_id\":\"\",\"payload\":{}}\n"
	testing.expect_value(t,
		write_private_file(events_path(ws), strings.concatenate({"broken\n", valid})),
		nil)

	_, err := load_store(ws)
	testing.expect_value(t, err, Engine_Error.Storage_Error)
}
