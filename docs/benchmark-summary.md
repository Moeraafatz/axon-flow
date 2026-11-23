### Measured Benchmarks (Apple Silicon (arm64) · Version 26.7.2 (Build 25G332))

- **Macro Compiler Compression:** `47` noisy raw events → **`7` semantic steps** (`85.1%` reduction in `0.076 ms`)
- **CSV Batch Throughput:** `10000` CSV rows parsed, interpolated & AX-verified in **`11352.6 ms`** (`881 rows/s`)

#### 1. Replay Survival Across UI Mutations (60 trials each)

| Desktop Mutation Scenario | Trials | Axon Flow (Semantic AX) | Pixel Clicker |
| :--- | ---: | ---: | ---: |
| Window Moved | 60 | **100.0%** | 0.0% |
| Window Resized | 60 | **100.0%** | 0.0% |
| Sidebar Toggled | 60 | **100.0%** | 0.0% |
| 2nd Display Shift | 60 | **100.0%** | 0.0% |
| Label Count Drift | 60 | **100.0%** | 0.0% |

#### 2. Semantic AX Tree Resolution Speed

| Accessibility Tree Size | Resolution p50 | Resolution p95 |
| ---: | ---: | ---: |
| 100 AX nodes | **0.390 ms** | **0.953 ms** |
| 250 AX nodes | **1.027 ms** | **2.258 ms** |
| 500 AX nodes | **2.109 ms** | **4.710 ms** |
| 1000 AX nodes | **4.166 ms** | **5.009 ms** |
