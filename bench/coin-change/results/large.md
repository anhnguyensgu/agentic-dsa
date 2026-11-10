| Command | Mean Wall Time [ms] | Change | Factor |
|:---|---:|---:|:---|
| `zig` | 400.0 ± 72.2 |  |  |
| `zig-simd` | 128.1 ± 3.7 | -68.0% | (3.1x faster) |
| `cpp-clang` | 461.5 ± 39.7 | +15.4% |  |
| `rust` | 576.2 ± 45.1 | +44.0% | (1.4x slower) |
| `rust-unchecked` | 378.4 ± 28.3 | -5.4% |  |
| `cpp-clang-novec` | 610.7 ± 48.2 | +52.7% | (1.5x slower) |
| `rust-novec` | 726.0 ± 34.1 | +81.5% | (1.8x slower) |
| `cpp-gcc` | 152.2 ± 17.9 | -61.9% | (2.6x faster) |
| `odin` | 863.7 ± 59.4 | +115.9% | (2.2x slower) |
| `odin-unchecked` | 314.8 ± 17.9 | -21.3% |  |
