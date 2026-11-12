| Command | Mean Wall Time [ms] | Change | Factor |
|:---|---:|---:|:---|
| `odin-unchecked-multi` | 543.1 ± 18.0 |  |  |
| `odin-multi` | 628.2 ± 13.1 | +15.7% |  |
| `rust-unchecked-multi` | 518.0 ± 19.8 | -4.6% |  |
| `rust-multi` | 539.3 ± 36.1 | -0.7% |  |
| `cpp-gcc-multi` | 589.2 ± 14.5 | +8.5% |  |
| `cpp-clang-multi` | 544.3 ± 31.6 | +0.2% |  |
| `zig-multi` | 545.5 ± 34.8 | +0.4% |  |
| `odin-unchecked-acc` | 458.3 ± 30.0 | -15.6% |  |
| `odin-acc` | 499.3 ± 26.6 | -8.1% |  |
| `rust-unchecked-acc` | 431.4 ± 15.9 | -20.6% |  |
| `rust-acc` | 444.8 ± 20.9 | -18.1% |  |
| `cpp-gcc-acc` | 474.1 ± 22.2 | -12.7% |  |
| `cpp-clang-acc` | 485.8 ± 41.4 | -10.6% |  |
| `zig-acc` | 408.3 ± 19.1 | -24.8% |  |
| `odin-unchecked` | 241.4 ± 9.4 | -55.5% | (2.2x faster) |
| `odin` | 614.0 ± 9.3 | +13.1% |  |
| `cpp-gcc` | 93.5 ± 7.6 | -82.8% | (5.8x faster) |
| `rust-novec` | 550.9 ± 21.9 | +1.4% |  |
| `cpp-clang-novec` | 381.7 ± 21.0 | -29.7% |  |
| `rust-unchecked` | 280.8 ± 17.6 | -48.3% | (1.9x faster) |
| `rust` | 439.0 ± 11.7 | -19.2% |  |
| `cpp-clang` | 338.5 ± 20.9 | -37.7% | (1.6x faster) |
| `zig-simd` | 90.4 ± 0.3 | -83.4% | (6.0x faster) |
| `zig` | 271.3 ± 36.5 | -50.0% | (2.0x faster) |
