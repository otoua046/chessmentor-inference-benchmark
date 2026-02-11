## **Project Proposal**

**Student:** Sam Touahri – 300234041

**Course:** SEG4180

**Semester:** Winter 2026

### **Abstract**

Modern mobile applications increasingly rely on machine-learning inference, yet there is no clear consensus on whether inference should execute locally on the device or be delegated to a remote server. This project presents a systems-level evaluation of **on-device versus server-side computer vision inference** using a **mobile chessboard recognition application** as a controlled case study.

The application, developed as part of an existing capstone project, captures images of digital chessboards (chess.com) and performs structured visual recognition to extract board-state information. Leveraging this well-defined real-world vision task allows the project to focus on **measurement, benchmarking, and analysis** rather than feature development. The objective is to quantitatively compare **latency, energy consumption, and accuracy** under controlled conditions and to identify practical trade-offs that inform real-world mobile ML deployment decisions.

---

### **Project Objectives**

1. Implement two functionally equivalent inference pipelines:
    - **Pipeline A:** On-device inference within the mobile application
    - **Pipeline B:** Server-side inference accessed via a network API
2. Ensure strict control of model parity, preprocessing, and confidence thresholds across both pipelines.
3. Benchmark and compare end-to-end latency, energy usage, and accuracy.
4. Analyze failure modes and identify scenarios where one deployment strategy outperforms the other.
5. Demonstrate how an existing capstone system can be extended to support rigorous systems-level evaluation without architectural changes.

---

### **System Architecture Overview**

The system is implemented as an extension of an existing mobile vision application, allowing both inference pipelines to be evaluated under identical user interactions and data flows. The vision task consists of detecting and interpreting chessboard state from captured images, providing a repeatable and structured workload for benchmarking.

- **Client (Mobile App):** Image capture and identical preprocessing; executes inference locally (Pipeline A) or transmits input to a server (Pipeline B).
- **Server (Pipeline B only):** Hosts the same trained model with frozen weights and returns inference results to the client.

---

### **Evaluation Metrics**

- **Latency:** End-to-end time from image capture to final output, with breakdowns for preprocessing, inference, and network overhead.
- **Energy Consumption:** Battery usage per inference and under sustained workloads, measured using mobile energy diagnostics.
- **Accuracy:** Detection and classification accuracy against ground-truth labels, including full output correctness and per-component error rates.
- **Failure Analysis:** Qualitative and quantitative analysis under challenging conditions (lighting variation, angle distortion, sustained usage).

---

### **Deliverables**

1. Two validated inference pipelines (on-device and server-side).
2. A reproducible benchmarking and measurement harness.
3. Quantitative comparison plots and tables.
4. A final technical report summarizing results, trade-offs, and deployment recommendations.

---

### **Timeline**

- **Weeks 1–2:** Pipeline integration and validation
- **Weeks 3–5:** Benchmarking and data collection
- **Weeks 6–7:** Analysis and failure-case evaluation
- **Weeks 8–9:** Report writing and final refinement

---

### **Expected Outcome**

The project will produce a data-driven comparison of on-device versus server-side inference, yielding actionable insights into latency, energy efficiency, and accuracy trade-offs. The results will inform practical deployment decisions for real-world mobile ML systems, with emphasis on engineering rigor rather than feature development.