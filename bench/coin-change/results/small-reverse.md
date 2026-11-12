| Command | Mean Wall Time [ms] | Change | Factor |
|:---|---:|---:|:---|
| `odin-unchecked-multi` | 884.8 ± 26.4 |  |  |
| `odin-multi` | 908.3 ± 60.6 | +2.7% |  |
| `rust-unchecked-multi` | 1033.4 ± 42.4 | +16.8% |  |
| `rust-multi` | 1073.2 ± 57.1 | +21.3% |  |
| `cpp-gcc-multi` | 987.1 ± 28.1 | +11.6% |  |
| `cpp-clang-multi` | 926.5 ± 34.0 | +4.7% |  |
| `zig-multi` | 930.8 ± 41.9 | +5.2% |  |
| `odin-unchecked-acc` | 1002.1 ± 42.0 | +13.3% |  |
| `odin-acc` | 989.9 ± 35.0 | +11.9% |  |
| `rust-unchecked-acc` | 999.5 ± 40.0 | +13.0% |  |
| `rust-acc` | 986.7 ± 37.0 | +11.5% |  |
| `cpp-gcc-acc` | 1278.2 ± 11.9 | +44.5% | (1.4x slower) |
| `cpp-clang-acc` | 1011.2 ± 47.2 | +14.3% |  |
| `zig-acc` | 986.4 ± 41.2 | +11.5% |  |
| `odin-unchecked` | 854.2 ± 21.0 | -3.5% |  |
| `odin` | 1006.5 ± 36.0 | +13.8% |  |
| `cpp-gcc` | 1014.0 ± 20.3 | +14.6% |  |
| `rust-novec` | 1005.0 ± 72.4 | +13.6% |  |
| `cpp-clang-novec` | 864.1 ± 9.6 | -2.3% |  |
| `rust-unchecked` | 892.1 ± 23.7 | +0.8% |  |
| `rust` | 1050.3 ± 95.7 | +18.7% |  |
| `cpp-clang` | 883.4 ± 26.8 | -0.2% |  |
| `zig-simd` | 1156.0 ± 114.9 | +30.7% | (1.3x slower) |
| `zig` | 1044.5 ± 58.8 | +18.1% |  |
