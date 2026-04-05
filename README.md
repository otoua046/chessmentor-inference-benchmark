# ChessMentor ♟️ — Mobile Edge Inference Benchmark

This repository contains a **systems-level benchmarking study** comparing **on-device (edge)** vs **hosted (cloud API)** computer vision inference using the ChessMentor mobile application as a case study.

> Focus: **measurement, reproducibility, and deployment trade-offs** — not feature development.

---

## 🔍 Overview

The project evaluates a two-stage mobile vision pipeline:

1. **Board Detection** (localization + crop)
2. **Piece Detection** (object detection/classification)

Two deployment modes are implemented and benchmarked:

- **Pipeline A (Local):** Full on-device inference using CoreML
- **Pipeline B (Hosted):** Remote inference via Roboflow API

All experiments are executed on a fixed input image and logged to CSV for analysis.

---

## 🎯 Key Contributions

- Integrated **dual inference backends** (local + hosted) in a single app
- Built a **benchmark logging layer** (CSV-based, stage-level timing)
- Implemented an **automated fixed-image runner** for large-scale experiments
- Collected and analyzed **300+ runs** with controlled conditions
- Identified a **model-level bottleneck** (legacy vs hardware-optimized models)

---

## 🏗 High-Level Architecture

```
iOS App
   │
   ├── Board Detection (local or hosted)
   │
   ├── Piece Detection (local or hosted)
   │
   └── Benchmark Logger (optional, CSV)
```

---

## ⚙️ Installation

### Requirements
- macOS + Xcode (latest recommended)
- iOS device or simulator

### Steps

1. Clone the repository
```bash
git clone https://github.com/otoua046/mobile-edge-inference-benchmark.git
cd mobile-edge-inference-benchmark
```

2. Open the project in Xcode
```bash
open chessMentor.xcodeproj
```

3. Select a valid iOS device or simulator

4. Build and run the app

---

## 🧪 Enabling Benchmark Mode (IMPORTANT)

Benchmarking is **disabled by default**.

To enable it, you must set a scheme environment variable in Xcode.

### Steps:

1. In Xcode: **Product → Scheme → Edit Scheme**
2. Select **Run → Arguments**
3. Under **Environment Variables**, add:

| Key                         | Value |
|-----------------------------|-------|
| ENABLE_BENCHMARK_LOGGING    | 1     |
| SHOW_BENCHMARK_CONTROLS     | 1     |

### What this does

When enabled:
- Activates the **benchmark logging layer**
- Creates CSV output in the app’s Documents directory
- Enables the **Photo Benchmark Runner UI**

When disabled:
- The app behaves normally
- No benchmark data is recorded

---

## 📊 Benchmarking System

### Logged Metrics
Each run records:

- `board_ms` → board detection latency
- `piece_ms` → piece detection latency
- `total_ms` → full perception latency (excluding engine)
- `detection_count`
- `success / failure`

### Output

CSV file:
The generated CSV file can be accessed from the device file system. On a physical iPhone, it is available within the app’s container under the Files app (On My iPhone → ChessMentor → Documents), or via Xcode’s device file browser.


---

## 🔁 Automated Benchmark Runner

- Uses a **fixed bundled image** (`ui_test_board`)
- Runs sequential inference (no UI simulation)
- Supports:
  - warm-up runs
  - measured runs (e.g., 150+)

This ensures:
- reproducibility
- stable latency measurements
- removal of camera noise

---

## 📈 Key Findings (Summary)

- **~38× speedup** for on-device inference vs hosted
- Local pipeline achieves **~63 ms latency** (~15 FPS)
- Hosted pipeline averages **~2.4 seconds** with high variance
- **Board detection is the bottleneck (~70%)**

### Critical Insight

A legacy “fast” model (Roboflow 3.0) is **slower** than a newer “accurate” YOLOv11 model due to:
- better CoreML compatibility
- improved execution graph
- removal of inefficient post-processing (e.g., NMS)

---

## 📄 Report & Dataset

- Technical report (PDF): [View Report](./report/Mobile_Edge_Inference_Benchmark.pdf)
- Benchmark dataset (CSV): available in the [`/benchmark/`](./benchmark/) directory

---

## 🔀 Branch Selection (Pipeline A vs Pipeline B)

This repository contains multiple branches corresponding to different inference pipelines:

- **Pipeline A (Local):** on-device CoreML inference
- **Pipeline B (Hosted):** remote Roboflow API inference

To reproduce results or test a specific setup, switch to the appropriate branch:

```bash
git checkout <branch-name>
```

⚠️ Note:
- The application behavior and UI are intentionally very similar across branches
- Always verify which branch you are on before running experiments
- Benchmark results depend on the active pipeline implementation

---

---

## 📚 Academic Context

This work was developed as part of:

**SEG4180 / CEG4195 — Applied Machine Learning for Software and Computer Engineering**

Focus areas include:
- ML systems
- deployment trade-offs
- performance benchmarking
- edge vs cloud inference

---

## 👤 Author

Oussama Touahri  
University of Ottawa  
Software Engineering