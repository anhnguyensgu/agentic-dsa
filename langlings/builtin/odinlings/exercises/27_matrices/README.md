# Matrices and quaternions

`matrix[R, C]T` is a built-in type for small matrices (up to 64 elements, 8
by 8). Literals are written row by row, even though the memory is
column-major. `*` is the matrix product (`m * v` multiplies a column vector
`[C]T`), `m[r, c]` indexes, and `intrinsics.transpose`,
`intrinsics.hadamard_product` and friends live in `base:intrinsics`.

Quaternions are built in too: `quaternion128` is four `f32`s, and
`core:math/linalg` has the usual helpers, like `quaternion_angle_axis` to
build a rotation and `mul` to rotate a vector with it.

Floating-point results are rarely exact, so compare them with a tolerance.

## Further information

- [Matrix type](https://odin-lang.org/docs/overview/#matrix-type)
- [Complex numbers and quaternions](https://odin-lang.org/docs/overview/#complex-numbers-and-quaternions)
- Package docs: [core:math/linalg](https://pkg.odin-lang.org/core/math/linalg/)
- Demo file: `matrix_type`, `quaternions`
