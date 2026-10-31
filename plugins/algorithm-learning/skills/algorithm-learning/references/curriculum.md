# Default study path

A starting point, not a rule: follow it, reorder it from the learner's record,
or let a more specific learning-path skill replace it. The tools know nothing
about it.

Groups are listed in study order; each builds on the groups it names. Pick
LeetCode problems by tag with `algo judge leetcode random --tag <tag>` or
`list`, and Exercism exercises as `exercism:<slug>` problem keys (Odin track).
The LeetCode tags were checked against leetcode.com on 2026-10-20. Do not show
tags to the learner in independent work.

| Group | Title | Builds on | LeetCode tags | Exercism exercises |
| --- | --- | --- | --- | --- |
| `arrays-hashing` | Arrays and hashing | — | `array`, `hash-table`, `string`, `prefix-sum`, `counting` | `isogram`, `pangram`, `nucleotide-count`, `hamming`, `rna-transcription`, `word-count`, `anagram` |
| `two-pointers` | Two pointers | `arrays-hashing` | `two-pointers` | `reverse-string`, `pythagorean-triplet` |
| `stack` | Stack | `arrays-hashing` | `stack`, `monotonic-stack` | `matching-brackets`, `forth` |
| `binary-search` | Binary search | `arrays-hashing` | `binary-search` | `binary-search` |
| `sliding-window` | Sliding window | `two-pointers` | `sliding-window` | `series`, `largest-series-product` |
| `linked-list` | Linked list | `two-pointers` | `linked-list` | `linked-list`, `simple-linked-list`, `circular-buffer` |
| `trees` | Trees | `binary-search`, `linked-list` | `tree`, `binary-tree`, `binary-search-tree` | `binary-search-tree`, `zipper` |
| `tries` | Tries | `trees` | `trie` | — |
| `heap` | Heap and priority queue | `trees` | `heap-priority-queue` | — |
| `backtracking` | Backtracking | `trees` | `backtracking` | `dominoes`, `zebra-puzzle` |
| `intervals` | Intervals | `heap` | `sorting`, `sweep-line` | — |
| `greedy` | Greedy | `heap` | `greedy` | — |
| `graphs` | Graphs | `backtracking` | `graph`, `depth-first-search`, `breadth-first-search`, `union-find`, `topological-sort` | `two-bucket`, `relative-distance` |
| `advanced-graphs` | Advanced graphs | `graphs`, `heap` | `shortest-path`, `minimum-spanning-tree` | — |
| `dp-1d` | 1-D dynamic programming | `backtracking` | `dynamic-programming`, `memoization` | `change` |
| `dp-2d` | 2-D dynamic programming | `dp-1d`, `graphs` | `dynamic-programming`, `matrix` | `knapsack`, `book-store` |
| `bit-manipulation` | Bit manipulation | `arrays-hashing` | `bit-manipulation`, `bitmask` | `grains`, `eliuds-eggs`, `allergies`, `intergalactic-transmission` |
| `math-geometry` | Math and geometry | `arrays-hashing` | `math`, `geometry`, `number-theory`, `matrix` | `leap`, `difference-of-squares`, `collatz-conjecture`, `armstrong-numbers`, `perfect-numbers`, `darts`, `triangle`, `sieve`, `all-your-base`, `queen-attack` |

Record concept IDs as `<group>/<pattern>` for the pattern the learner actually
exercised, such as `graphs/topological-sort`, and reuse IDs already in your
record instead of inventing synonyms.
