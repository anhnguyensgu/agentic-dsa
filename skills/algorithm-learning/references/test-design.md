# Adversarial test design

Use this reference when validating a competitive-programming solution beyond official samples. The goal is to expose plausible wrong solutions, not to accumulate many easy cases. Keep testing separate from claims about understanding: a passing local campaign is evidence about the current artifact, not proof that the learner understands it or that a remote hidden judge will accept it.

## Preserve assessment integrity

In `independent`, `assessment`, and `review` modes, first ask the learner to propose edge cases and predicted outputs. Do not reveal an algorithm, invariant, or implementation defect merely by naming a test. A boundary prompt is normally hint level 1; a test that exposes the central invariant or required algorithm can be level 2 or 3. Record the actual disclosure.

Do not silently repair learner code, write an optimized solution for comparison, or convert generated expected values into verified evidence without a valid oracle.

## Build a risk map

Before generating cases, extract the exact contract:

- input ranges, total-size limits, number of test cases, and whether values may repeat;
- ordering, uniqueness, connectivity, reachability, and other guaranteed structure;
- output semantics, tie-breaking, accepted permutations, and numeric tolerance;
- integer widths, negative values, modular arithmetic, and overflow-prone intermediate expressions;
- time and memory limits, including aggregate rather than per-case bounds.

Partition each relevant dimension into minimum, just above minimum, ordinary, just below maximum, and maximum. Add values immediately around every behavioral threshold. For each proposed case, state the bug class or property it targets; remove redundant cases unless they improve diagnosis.

## Test campaign

Run tests in escalating tiers so cheap, clear failures appear first.

### 1. Contract and degenerate cases

Cover empty inputs only when legal, singleton inputs, the smallest composite structure, all-equal values, no-op answers, impossible cases, and answers at the first and last valid position. Check formatting, multiple test cases, and state leakage between cases.

### 2. Boundary interactions

Do not test boundaries only in isolation. Combine them:

- minimum size with extreme values;
- maximum size with the simplest structure;
- duplicates at a decision boundary;
- thresholds at `k-1`, `k`, and `k+1`;
- answers touching both ends of an array or interval;
- negative, zero, and positive values where signs are legal.

Include arithmetic cases that overflow likely intermediate types even when the final answer fits. For floating point, test near comparison boundaries and use the problem's checker tolerance rather than invented exact equality.

### 3. Structural adversaries

Select cases by problem family when applicable:

- **Arrays and sorting:** already sorted, reverse sorted, all equal, heavy duplicates, alternating extremes, one displaced element, and coordinate gaps.
- **Two pointers or windows:** optimum at either boundary, repeated shrink/expand, no valid window, every window valid, and duplicate values invalidating monotonic assumptions.
- **Binary search:** absent target, first/last occurrence, duplicate plateau, one-element range, and predicates switching at either endpoint.
- **Greedy:** ties, locally attractive traps, nested or overlapping choices, delayed reward, and cases requiring exchange reasoning.
- **Prefix sums or hashing:** repeated prefix values, zero-sum spans, collisions in logical keys, and negative values that break sliding-window assumptions.
- **Stacks and queues:** monotone increasing/decreasing input, equal elements, alternating peaks, and delayed cleanup at end of input.
- **Trees and graphs:** isolated/minimal graph, path, star, balanced and highly skewed tree, cycle, disconnected components when legal, parallel edges/self-loops when legal, multiple shortest paths, and unreachable nodes.
- **Shortest paths:** zero-weight edges when legal, stale priority-queue entries, equal distances, large path sums, and a cheaper route discovered late.
- **Disjoint sets:** repeated unions, already-connected endpoints, long chains, and interleaved queries.
- **Dynamic programming:** base cases, unreachable states, multiple optimal transitions, order-dependent updates, values larger than the target, and cases distinguishing 0/1 from unbounded reuse.
- **Recursion/backtracking:** no solution, one solution, many symmetric solutions, duplicate candidates, and maximum depth.
- **Number theory:** zero/one when legal, primes, prime powers, coprime and non-coprime pairs, repeated factors, and values near numeric limits.

### 4. Wrong-solution killers

List plausible incorrect implementations and design the smallest case that distinguishes each from the specification. Typical mutants include:

- wrong strictness (`<` versus `<=`) or inclusive/exclusive endpoint;
- incorrect initialization or missing final flush;
- assuming distinct, sorted, positive, connected, or reachable input without a guarantee;
- choosing a locally optimal item with the wrong tie-break;
- marking graph nodes visited too early;
- reusing an updated DP state in the wrong direction;
- comparing only values while losing original identity;
- using an insufficient integer width;
- meeting average complexity but failing a worst-case shape.

Prefer a compact discriminating case over a large opaque one.

### 5. Differential and property testing

For bounded small domains, compare the submission with an independently checked brute-force or reference oracle. Enumerate tiny domains exhaustively when practical, then run reproducible randomized tests with recorded seeds.

A reference implementation is not trustworthy merely because it looks simple. Validate it with hand-derived cases and properties first, and keep it structurally different from the candidate solution where possible.

Useful properties include invariants, conservation laws, monotonicity, idempotence, permutation invariance, and equivalence under a semantics-preserving transformation. Use only properties justified by the problem. A property violation can prove failure; satisfying a few properties does not prove correctness.

On failure, preserve the original input and shrink it while retaining the mismatch. Record the minimized counterexample, seed, candidate output, oracle output, comparator, and source hashes.

### 6. Complexity and resource attacks

Construct maximum-size cases that trigger the candidate's worst plausible behavior rather than merely large random input: degenerate recursion depth, repeated hash/map work, dense graph exploration, pathological queue growth, maximum output, or an `O(n²)` pattern hidden by friendly samples.

Run with explicit time, memory, output, and process limits. A timeout indicates resource failure, not a wrong-answer oracle. Avoid claiming a complexity bound from one fast run; combine source analysis with measured stress behavior.

## Oracle and checker rules

Use expected outputs only when based on an official example, manually checked derivation, independently validated reference implementation, or justified property. Mark all other generated cases unverified.

Match the real judging semantics:

- exact tokens or whitespace-insensitive tokens as specified;
- absolute/relative floating tolerance where specified;
- set, multiset, or permutation comparison only when output order is irrelevant;
- a dedicated checker for constructive outputs, multiple valid answers, or optimization objectives.

Validate the checker with both known-valid and deliberately invalid outputs. A permissive checker can make broken solutions appear correct.

## Reporting and stopping

Report separately:

1. compilation/runtime status;
2. verified functional cases passed and failed;
3. unverified exploratory cases;
4. differential/property campaign size and reproducible seed range;
5. resource-limit results;
6. remote judge result, if any.

Stop only after every identified risk has a targeted test or an explicit reason it cannot be tested locally, all discovered failures have regression cases, and the final source snapshot has rerun the relevant campaign. Say “no counterexample found” rather than “correct.” Only the relevant remote judge establishes acceptance against its hidden suite.
