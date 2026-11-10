| Command | Mean Wall Time [ms] | Change | Factor |
|:---|---:|---:|:---|
| `zig` | 379.1 ± 49.7 |  |  |
| `cpp-clang` | 485.7 ± 61.2 | +28.1% |  |
| `rust` | 626.3 ± 96.3 | +65.2% | (1.7x slower) |
| `rust-unchecked` | 384.2 ± 48.6 | +1.4% |  |
| `cpp-clang-novec` | 597.4 ± 63.6 | +57.6% | (1.6x slower) |
| `rust-novec` | 766.7 ± 62.5 | +102.3% | (2.0x slower) |
| `cpp-gcc` | 150.7 ± 18.5 | -60.2% | (2.5x faster) |
| `odin` | 914.0 ± 102.7 | +141.1% | (2.4x slower) |
| `odin-unchecked` | 378.5 ± 60.2 | -0.2% |  |
