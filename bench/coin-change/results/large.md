| Command | Mean Wall Time [ms] | Change | Factor |
|:---|---:|---:|:---|
| `zig` | 249.4 ± 2.0 |  |  |
| `cpp-clang` | 323.6 ± 3.4 | +29.7% |  |
| `rust` | 433.7 ± 2.8 | +73.9% | (1.7x slower) |
| `rust-unchecked` | 267.5 ± 15.8 | +7.3% |  |
| `cpp-clang-novec` | 386.7 ± 24.1 | +55.1% | (1.6x slower) |
| `rust-novec` | 533.9 ± 10.7 | +114.1% | (2.1x slower) |
| `cpp-gcc` | 89.6 ± 0.3 | -64.1% | (2.8x faster) |
