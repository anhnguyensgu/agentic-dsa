| Command | Mean Wall Time [ms] | Change | Factor |
|:---|---:|---:|:---|
| `odin-unchecked` | 334.7 ± 46.0 |  |  |
| `odin` | 869.5 ± 61.1 | +159.8% | (2.6x slower) |
| `cpp-gcc` | 142.0 ± 5.6 | -57.6% | (2.4x faster) |
| `rust-novec` | 740.3 ± 31.2 | +121.2% | (2.2x slower) |
| `cpp-clang-novec` | 593.9 ± 21.3 | +77.5% | (1.8x slower) |
| `rust-unchecked` | 372.9 ± 22.6 | +11.4% |  |
| `rust` | 581.0 ± 95.6 | +73.6% | (1.7x slower) |
| `cpp-clang` | 491.6 ± 65.4 | +46.9% | (1.5x slower) |
| `zig-simd` | 127.6 ± 4.3 | -61.9% | (2.6x faster) |
| `zig` | 400.0 ± 94.6 | +19.5% |  |
