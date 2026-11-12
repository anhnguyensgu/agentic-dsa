| Command | Mean Wall Time [ms] | Change | Factor |
|:---|---:|---:|:---|
| `zig` | 258.3 ± 18.3 |  |  |
| `zig-simd` | 96.9 ± 5.7 | -62.5% | (2.7x faster) |
| `cpp-clang` | 353.3 ± 45.7 | +36.8% | (1.4x slower) |
| `rust` | 454.9 ± 25.0 | +76.1% | (1.8x slower) |
| `rust-unchecked` | 273.7 ± 16.1 | +5.9% |  |
| `cpp-clang-novec` | 362.0 ± 29.1 | +40.1% | (1.4x slower) |
| `rust-novec` | 543.3 ± 23.0 | +110.3% | (2.1x slower) |
| `cpp-gcc` | 93.2 ± 5.4 | -63.9% | (2.8x faster) |
| `odin` | 620.7 ± 15.5 | +140.3% | (2.4x slower) |
| `odin-unchecked` | 231.4 ± 1.0 | -10.4% |  |
| `zig-acc` | 409.6 ± 16.9 | +58.6% | (1.6x slower) |
| `cpp-clang-acc` | 469.5 ± 25.5 | +81.7% | (1.8x slower) |
| `cpp-gcc-acc` | 475.6 ± 17.2 | +84.1% | (1.8x slower) |
| `rust-acc` | 438.8 ± 14.4 | +69.8% | (1.7x slower) |
| `rust-unchecked-acc` | 432.9 ± 18.9 | +67.6% | (1.7x slower) |
| `odin-acc` | 506.1 ± 37.0 | +95.9% | (2.0x slower) |
| `odin-unchecked-acc` | 447.1 ± 17.6 | +73.1% | (1.7x slower) |
| `zig-multi` | 548.5 ± 28.4 | +112.3% | (2.1x slower) |
| `cpp-clang-multi` | 546.5 ± 31.6 | +111.6% | (2.1x slower) |
| `cpp-gcc-multi` | 588.2 ± 35.2 | +127.7% | (2.3x slower) |
| `rust-multi` | 519.7 ± 22.7 | +101.2% | (2.0x slower) |
| `rust-unchecked-multi` | 523.1 ± 29.9 | +102.5% | (2.0x slower) |
| `odin-multi` | 626.6 ± 14.4 | +142.5% | (2.4x slower) |
| `odin-unchecked-multi` | 558.4 ± 22.7 | +116.2% | (2.2x slower) |
