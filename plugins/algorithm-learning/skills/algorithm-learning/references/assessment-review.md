# Assessment and review

Score each applicable dimension independently: recognition, approach or invariant, correctness explanation, complexity, implementation and testing, and transfer. Use `unknown` when unobserved. Scores are 0 incorrect, 1 partial, 2 correct with meaningful prompting, and 3 independently justified. Record each as an `assessment_recorded` event citing the `event_id`s of the kept evidence it rests on, with a short rationale.

An independent qualifying solve needs all of the following:

- an independent, assessment, or review session;
- a fresh attempt;
- no algorithm-bearing solution exposure, translation, or agent-authored algorithm change;
- assistance no higher than level 1;
- score 3 with evidence for approach, correctness, and complexity;
- at least one nontrivial verified case or relevant judge result, from a `runner_observed` or `job_observed` event whose source hash still matches the file, with no unchecked case used as proof.

An accepted submission alone does not establish understanding. Assisted or copied accepted work remains assisted. Imported historical solves are prior practice unless their assistance and reasoning evidence are available.

Concept states are `unknown`, `introduced`, `practicing`, `independent`, and `retained`. Retained understanding requires two distinct qualifying problems including a transfer task, plus a successful delayed retrieval at least three days after the relevant exposure.

You schedule reviews yourself, as `review_updated` events. New independent or assisted study creates a one-day retrieval item. Independent review successes advance through 3, 7, 21, and 60 days from completion. Help or a conceptual lapse resets to one day. Tool failure and interruption leave interval progress unchanged. Snoozing changes visibility or date without awarding completion.

Report execution, judge outcomes, assistance, and learning as separate views. Preserve historical achievements after a lapse while showing current recall uncertainty.
