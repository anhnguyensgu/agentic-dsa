| Command | Mean Wall Time [ms] | Change | Factor |
|:---|---:|---:|:---|
| `odin-unchecked` | 369.8 ± 78.0 |  |  |
| `odin` | 912.6 ± 94.1 | +146.8% | (2.5x slower) |
| `cpp-gcc` | 144.4 ± 7.8 | -61.0% | (2.6x faster) |
| `rust-novec` | 776.8 ± 101.0 | +110.1% | (2.1x slower) |
| `cpp-clang-novec` | 623.3 ± 69.3 | +68.6% | (1.7x slower) |
| `rust-unchecked` | 413.1 ± 59.9 | +11.7% |  |
| `rust` | 556.2 ± 42.6 | +50.4% | (1.5x slower) |
| `cpp-clang` | 491.9 ± 71.5 | +33.0% | (1.3x slower) |
| `zig` | 377.5 ± 45.6 | +2.1% |  |
