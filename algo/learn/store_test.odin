package learn

// Deterministic domain and storage tests (section 18): scheduling, identity,
// deduplication, and event replay with a pinned clock and temporary
// workspaces. Each test allocates from the temp allocator and frees it all at
// the end, so leak tracking stays meaningful.

import "core:os"
import "core:strings"
import "core:testing"
import "core:time"

FAKE_NOW :: 1758300000 // 2025-09-19T16:40:00Z

fake_now :: proc() -> time.Time {
	return time.unix(FAKE_NOW, 0)
}

temp_workspace :: proc(t: ^testing.T) -> string {
	dir, err := os.make_directory_temp("", "algolearn-test-*", context.allocator)
	testing.expect(t, err == nil)
	return dir
}

VALID_RECORD :: `{"schema_version":1,"event_id":"ev_000001","sequence":1,"workspace_id":"ws_x","timestamp":"2025-09-19T15:20:00Z","actor":"agent:test","type":"session_started","request_id":"","request_hash":"","session_id":"s1","attempt_id":"","payload":{}}` + "\n"

// -- schedule ------------------------------------------------------------------

@(test)
schedule_independent_successes_advance_and_cap :: proc(t: ^testing.T) {
	// A new item's first independent success schedules the 3-day interval,
	// then 7, 21, and 60 days, capped at 60.
	expected := [?]struct {
		index, days: int,
	}{{1, 3}, {2, 7}, {3, 21}, {3, 60}, {3, 60}}
	index := 0
	for want in expected {
		days: int
		index, days = next_interval(index, .Independent_Correct)
		testing.expect_value(t, index, want.index)
		testing.expect_value(t, days, want.days)
	}
}

@(test)
schedule_help_lapse_and_neutral_outcomes :: proc(t: ^testing.T) {
	// Help and conceptual lapses reset to the initial interval.
	for outcome in ([?]Review_Outcome{.Correct_After_Help, .Incorrect_Recall}) {
		index, days := next_interval(3, outcome)
		testing.expect_value(t, index, 0)
		testing.expect_value(t, days, INITIAL_INTERVAL_DAYS)
	}
	// Tool failures and skips leave progress unchanged.
	for outcome in ([?]Review_Outcome{.Tool_Failure, .Skipped}) {
		index, days := next_interval(2, outcome)
		testing.expect_value(t, index, 2)
		testing.expect_value(t, days, 0)
	}
}

@(test)
schedule_due_dates_use_completion_time :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	index, due := apply_outcome(0, "2025-01-01T00:00:00Z", .Independent_Correct, fake_now())
	testing.expect_value(t, index, 1)
	testing.expect_value(t, due, "2025-09-22T16:40:00Z") // 3 days after completion

	_, due = apply_outcome(0, "2025-01-01T00:00:00Z", .Incorrect_Recall, fake_now())
	testing.expect_value(t, due, "2025-09-20T16:40:00Z") // 1 day after completion

	// A tool failure keeps the previous due date.
	_, due = apply_outcome(0, "2025-01-01T00:00:00Z", .Tool_Failure, fake_now())
	testing.expect_value(t, due, "2025-01-01T00:00:00Z")
}

// -- store ---------------------------------------------------------------------

@(test)
store_round_trip_dedup_and_revision :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	store, err := load_store(ws)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, store.revision, 0)

	// The first commit into an empty workspace expects revision 0.
	req := Request{request_id = "r1", request_hash = "h1", expected_revision = 0}
	ev, replayed, commit_err := commit_event(&store, "session_started", "agent:test", req, "s1", "", `{"objective":"o"}`)
	testing.expect_value(t, commit_err, nil)
	testing.expect(t, !replayed)
	testing.expect_value(t, ev.sequence, 1)
	testing.expect(t, strings.has_prefix(ev.event_id, "ev_"))
	testing.expect(t, strings.has_suffix(ev.event_id, "_000001"))
	testing.expect(t, strings.has_prefix(ev.workspace_id, "ws_"))

	// Reloading restores the same revision and event.
	reloaded, load_err := load_store(ws)
	testing.expect_value(t, load_err, nil)
	testing.expect_value(t, reloaded.revision, 1)
	testing.expect_value(t, len(reloaded.events), 1)
	testing.expect_value(t, reloaded.events[0].event_id, ev.event_id)
	testing.expect_value(t, reloaded.events[0].payload, `{"objective":"o"}`)

	// An identical repeat returns the existing event.
	again, replayed_again, again_err := commit_event(&reloaded, "session_started", "agent:test", {"r1", "h1", 1}, "s1", "", `{"objective":"o"}`)
	testing.expect_value(t, again_err, nil)
	testing.expect(t, replayed_again)
	testing.expect_value(t, again.event_id, ev.event_id)

	// Reusing the id with a different payload conflicts.
	_, _, conflict_err := commit_event(&reloaded, "session_started", "agent:test", {"r1", "h2", 1}, "s1", "", `{"objective":"changed"}`)
	testing.expect_value(t, conflict_err, Engine_Error.Request_Conflict)

	// A stale revision conflicts.
	_, _, stale_err := commit_event(&reloaded, "hint_delivered", "agent:test", {"r2", "h3", 0}, "s1", "", `{}`)
	testing.expect_value(t, stale_err, Engine_Error.Stale_Revision)

	// Unversioned callers (expected_revision < 0) accept the latest revision.
	_, _, latest_err := commit_event(&reloaded, "hint_delivered", "agent:test", {"r3", "h4", -1}, "s1", "", `{}`)
	testing.expect_value(t, latest_err, nil)

	after, after_err := load_store(ws)
	testing.expect_value(t, after_err, nil)
	testing.expect_value(t, after.revision, 2)
}

@(test)
store_preserves_truncated_tail_and_blocks_writes :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	truncated := `{"event_id":"ev_000002","sequence":2,"truncat`
	testing.expect_value(t, write_private_file(events_path(ws), strings.concatenate({VALID_RECORD, truncated})), nil)

	store, err := load_store(ws)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, store.revision, 1)
	testing.expect(t, store.tail_warning != "")

	// Writes are refused so the damaged tail is never silently dropped.
	_, _, commit_err := commit_event(&store, "hint_delivered", "agent:test", {"r1", "h1", 1}, "s1", "", `{}`)
	testing.expect_value(t, commit_err, Engine_Error.Storage_Error)

	// The original bytes are untouched.
	data, _ := os.read_entire_file(events_path(ws), context.allocator)
	testing.expect(t, strings.has_suffix(string(data), `"truncat`))
}

@(test)
store_middle_corruption_is_an_error :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	testing.expect_value(t, write_private_file(events_path(ws), strings.concatenate({"broken\n", VALID_RECORD})), nil)
	_, err := load_store(ws)
	testing.expect_value(t, err, Engine_Error.Storage_Error)
}

@(test)
event_payloads_decode_canonically :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// Key order on disk does not matter: equal payloads compare equal.
	a, a_ok := parse_event(`{"sequence":1,"type":"x","payload":{"b":1,"a":[2,{"d":3,"c":4}]}}`)
	b, b_ok := parse_event(`{"sequence":1,"type":"x","payload":{"a":[2,{"c":4,"d":3}],"b":1}}`)
	testing.expect(t, a_ok && b_ok)
	testing.expect_value(t, a.payload, b.payload)

	// A payload must be an object; a missing one reads as empty.
	_, array_ok := parse_event(`{"sequence":1,"type":"x","payload":[1]}`)
	testing.expect(t, !array_ok)
	missing, missing_ok := parse_event(`{"sequence":1,"type":"x"}`)
	testing.expect(t, missing_ok)
	testing.expect_value(t, missing.payload, EMPTY_OBJECT)
}
