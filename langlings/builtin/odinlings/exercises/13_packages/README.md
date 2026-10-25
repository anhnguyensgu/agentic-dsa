# Packages

A package is a directory of `.odin` files that all start with the same
`package name` line. There are no header files and no forward declarations,
and every file in the directory sees everything in the others.

`import "core:strings"` brings in a package from the `core` collection
(`base` and `vendor` are the other built-in collections), and
`import "shapes"` imports the directory `shapes` relative to the importing
file. An import is used by the last part of its path unless you give it
another name: `import str "core:strings"`.

Everything declared at the top level of a package can be used from other
packages. `@(private)` limits a declaration to its own package, and
`@(private="file")` to its own file.

`packages2` is a directory, not a single file: the runner builds the whole
`packages2` package, and you fix `packages2/shapes/shapes.odin`.

## Further information

- [Packages](https://odin-lang.org/docs/overview/#packages) and [import statements](https://odin-lang.org/docs/overview/#import-statement)
- [Exported names](https://odin-lang.org/docs/overview/#exported-names)
- [Authoring a package](https://odin-lang.org/docs/overview/#authoring-a-package) and [organizing packages](https://odin-lang.org/docs/overview/#organizing-packages)
