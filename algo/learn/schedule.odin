package learn

// Review scheduling policy (section 9 of AGENTIC_LEARNING.md).
//
// Initial review after 1 day; after an independently successful review,
// intervals of 3, 7, 21, then 60 days from the actual completion time,
// capped at 60. Assisted success or a conceptual lapse resets to the initial
// interval. Tool failures and skips leave progress unchanged.

import "core:time"

INITIAL_INTERVAL_DAYS :: 1
REVIEW_INTERVALS_DAYS :: [4]int{3, 7, 21, 60}

DAY :: 24 * time.Hour

Review_Outcome :: enum {
	Independent_Correct,
	Correct_After_Help,
	Incorrect_Recall,
	Tool_Failure,
	Skipped,
}

review_outcome_from_string :: proc(s: string) -> (Review_Outcome, bool) {
	switch s {
	case "independent_correct":
		return .Independent_Correct, true
	case "correct_after_help":
		return .Correct_After_Help, true
	case "incorrect_recall":
		return .Incorrect_Recall, true
	case "tool_failure":
		return .Tool_Failure, true
	case "skipped":
		return .Skipped, true
	}
	return .Skipped, false
}

// next_interval computes the new interval index and the number of days until
// the item is next due. `index` is the position in REVIEW_INTERVALS_DAYS used
// on this independent success; a new item starts at index 0 and is initially
// due after INITIAL_INTERVAL_DAYS. Independent successes therefore schedule
// 3, then 7, then 21, then 60 days, and stay at 60.
next_interval :: proc(index: int, outcome: Review_Outcome) -> (new_index: int, due_days: int) {
	new_index = index
	intervals := REVIEW_INTERVALS_DAYS
	#partial switch outcome {
	case .Independent_Correct:
		due_days = intervals[min(index, len(intervals) - 1)]
		new_index = min(index + 1, len(intervals) - 1)
	case .Correct_After_Help, .Incorrect_Recall:
		new_index = 0
		due_days = INITIAL_INTERVAL_DAYS
	case .Tool_Failure, .Skipped:
		// No negative learning inference; progress unchanged.
		due_days = 0
	}
	return
}

// apply_outcome folds an outcome into a review item. For Tool_Failure and
// Skipped the due date is preserved unchanged.
apply_outcome :: proc(
	index: int,
	due: string,
	outcome: Review_Outcome,
	completed_at: time.Time,
) -> (
	new_index: int,
	new_due: string,
) {
	ni, days := next_interval(index, outcome)
	if days == 0 {
		return index, due
	}
	return ni, rfc3339_utc(time.time_add(completed_at, time.Duration(days) * DAY))
}
