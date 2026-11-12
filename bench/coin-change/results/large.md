| Command | Mean Wall Time [ms] | Change | Factor |
|:---|---:|---:|:---|
| `zig` | 324.5 ± 28.1 |  |  |
| `zig-simd` | 114.6 ± 7.4 | -64.7% | (2.8x faster) |
| `cpp-clang` | 384.0 ± 12.9 | +18.4% |  |
| `rust` | 487.4 ± 28.2 | +50.2% | (1.5x slower) |
| `rust-unchecked` | 320.3 ± 18.6 | -1.3% |  |
| `cpp-clang-novec` | 511.7 ± 19.4 | +57.7% | (1.6x slower) |
| `rust-novec` | 636.8 ± 37.3 | +96.3% | (2.0x slower) |
| `cpp-gcc` | 123.1 ± 5.1 | -62.1% | (2.6x faster) |
| `odin` | 749.7 ± 50.4 | +131.1% | (2.3x slower) |
| `odin-unchecked` | 284.4 ± 24.3 | -12.4% |  |
| `zig-acc` | 511.2 ± 40.1 | +57.6% | (1.6x slower) |
| `cpp-clang-acc` | 858.5 ± 38.0 | +164.6% | (2.6x slower) |
| `cpp-gcc-acc` | 619.9 ± 42.8 | +91.0% | (1.9x slower) |
| `rust-acc` | 715.4 ± 27.5 | +120.5% | (2.2x slower) |
| `rust-unchecked-acc` | 707.3 ± 34.7 | +118.0% | (2.2x slower) |
| `odin-acc` | 908.5 ± 30.4 | +180.0% | (2.8x slower) |
| `odin-unchecked-acc` | 878.9 ± 26.4 | +170.9% | (2.7x slower) |
