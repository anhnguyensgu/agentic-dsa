# Tests

A test is a procedure marked `@(test)` that takes a `^testing.T`. `odin test`
finds and runs them in parallel, each with its own tracking allocator and
temp allocator, and reports leaks.

```odin
testing.expect(t, ok)                         // a condition
testing.expect_value(t, got, want)            // prints both on failure
testing.expectf(t, ok, "for %d", n)           // your own message
```

A failed expectation marks the test failed and keeps going. `return` after
it if the rest of the test makes no sense without it. Table-driven tests (a
slice of cases and a loop) are the usual way to cover many inputs.

Tests can live in the package they test, as in this course, or in a separate
package that imports it. Some useful `-define`s:
`-define:ODIN_TEST_NAMES=pkg.name` runs a single test, and
`-define:ODIN_TEST_FAIL_ON_BAD_MEMORY=true` turns leaks into failures (the
runner sets that one for you).

## Further information

- [Running tests](https://odin-lang.org/docs/testing/)
- Package docs: [core:testing](https://pkg.odin-lang.org/core/testing/)
