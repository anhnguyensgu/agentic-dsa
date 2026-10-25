# The implicit context

Every Odin procedure (with the default calling convention) receives a hidden
`context` value from its caller. It carries the current allocator, temp
allocator, logger, random generator, and a few user fields.

Assigning to `context.allocator` or `context.logger` changes them for the
rest of the current scope and for everything called from it. When the scope
ends, the old values come back, and a callee's changes never reach its
caller. This is how you change what third-party code does, such as where it
allocates or where it logs, without touching that code.

`core:log` writes through `context.logger`. The default logger discards
everything until you install one, for example
`log.create_console_logger()`.

## Further information

- [Implicit context system](https://odin-lang.org/docs/overview/#implicit-context-system)
- [Logging system](https://odin-lang.org/docs/overview/#logging-system)
- [Explicit context definition](https://odin-lang.org/docs/overview/#explicit-context-definition)
- Demo file: `implicit_context_system`, `explicit_context_definition`
