| Command | Mean Wall Time [ms] | Change | Factor |
|:---|---:|---:|:---|
| `odin-unchecked-acc` | 870.7 ± 32.2 |  |  |
| `odin-acc` | 918.8 ± 41.5 | +5.5% |  |
| `rust-unchecked-acc` | 722.1 ± 44.9 | -17.1% |  |
| `rust-acc` | 725.5 ± 43.5 | -16.7% |  |
| `cpp-gcc-acc` | 602.5 ± 28.8 | -30.8% | (1.4x faster) |
| `cpp-clang-acc` | 851.6 ± 38.9 | -2.2% |  |
| `zig-acc` | 506.0 ± 41.6 | -41.9% | (1.7x faster) |
| `odin-unchecked` | 267.4 ± 12.0 | -69.3% | (3.3x faster) |
| `odin` | 715.9 ± 27.6 | -17.8% |  |
| `cpp-gcc` | 122.2 ± 6.2 | -86.0% | (7.1x faster) |
| `rust-novec` | 629.6 ± 17.9 | -27.7% |  |
| `cpp-clang-novec` | 504.4 ± 22.3 | -42.1% | (1.7x faster) |
| `rust-unchecked` | 326.3 ± 33.1 | -62.5% | (2.7x faster) |
| `rust` | 476.9 ± 20.5 | -45.2% | (1.8x faster) |
| `cpp-clang` | 380.9 ± 16.1 | -56.3% | (2.3x faster) |
| `zig-simd` | 114.7 ± 9.4 | -86.8% | (7.6x faster) |
| `zig` | 319.8 ± 31.1 | -63.3% | (2.7x faster) |
