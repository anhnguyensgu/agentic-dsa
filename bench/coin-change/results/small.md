| Command | Mean Wall Time [ms] | Change | Factor |
|:---|---:|---:|:---|
| `zig` | 962.9 ± 24.9 |  |  |
| `zig-simd` | 1072.1 ± 49.5 | +11.3% |  |
| `cpp-clang` | 845.5 ± 20.0 | -12.2% |  |
| `rust` | 962.6 ± 31.6 | 0.0% |  |
| `rust-unchecked` | 881.1 ± 17.3 | -8.5% |  |
| `cpp-clang-novec` | 876.0 ± 25.9 | -9.0% |  |
| `rust-novec` | 964.1 ± 27.9 | +0.1% |  |
| `cpp-gcc` | 983.6 ± 12.1 | +2.1% |  |
| `odin` | 986.0 ± 35.7 | +2.4% |  |
| `odin-unchecked` | 851.8 ± 17.0 | -11.5% |  |
| `zig-acc` | 968.2 ± 18.6 | +0.6% |  |
| `cpp-clang-acc` | 998.3 ± 77.4 | +3.7% |  |
| `cpp-gcc-acc` | 1294.0 ± 24.9 | +34.4% | (1.3x slower) |
| `rust-acc` | 983.4 ± 40.2 | +2.1% |  |
| `rust-unchecked-acc` | 963.9 ± 16.7 | +0.1% |  |
| `odin-acc` | 982.7 ± 32.8 | +2.1% |  |
| `odin-unchecked-acc` | 985.2 ± 32.4 | +2.3% |  |
| `zig-multi` | 885.9 ± 30.6 | -8.0% |  |
| `cpp-clang-multi` | 910.4 ± 76.5 | -5.5% |  |
| `cpp-gcc-multi` | 984.2 ± 35.9 | +2.2% |  |
| `rust-multi` | 1076.2 ± 43.7 | +11.8% |  |
| `rust-unchecked-multi` | 1097.4 ± 70.5 | +14.0% |  |
| `odin-multi` | 904.1 ± 49.6 | -6.1% |  |
| `odin-unchecked-multi` | 904.7 ± 39.4 | -6.0% |  |
