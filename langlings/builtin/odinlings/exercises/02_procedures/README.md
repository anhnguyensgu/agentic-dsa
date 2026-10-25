# Procedures

Odin calls functions procedures. A procedure is a constant whose value is a
procedure literal:

```odin
add :: proc(a, b: int) -> int {
	return a + b
}
```

Parameters always need a type, results come after `->`, and several results go
in parentheses, optionally with names. Parameters are immutable inside the
procedure. Procedures can have default values, named arguments, variadic
parameters (`..int`), and explicit overload groups (`proc{a, b}`). Odin has no
implicit overloading.

## Further information

- [Procedures](https://odin-lang.org/docs/overview/#procedures)
- [Multiple results](https://odin-lang.org/docs/overview/#multiple-results) and [named results](https://odin-lang.org/docs/overview/#named-results)
- [Default values](https://odin-lang.org/docs/overview/#default-values) and [named arguments](https://odin-lang.org/docs/overview/#named-arguments)
- [Shadowing parameters](https://odin-lang.org/docs/overview/#shadowing-parameters)
- [Variadic parameters](https://odin-lang.org/docs/overview/#variadic-parameters)
- [Explicit procedure overloading](https://odin-lang.org/docs/overview/#explicit-procedure-overloading)
- Demo file: `named_proc_return_parameters`, `variadic_procedures`, `explicit_procedure_overloading`
