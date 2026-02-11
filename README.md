# ChessMentor ♟️ 
![image](https://github.com/user-attachments/assets/ec302138-d878-473d-9202-657dafdebc3a)

ChessMentor is an innovative iOS app that leverages augmented reality (AR) technology to analyze chess games and provide strategic move suggestions. By simply holding your device's camera above a chessboard, the app overlays helpful insights and recommendations directly onto the board, empowering players to make informed decisions and improve their gameplay.

### 🔗 Linked Repositories (Project Architecture)
ChessMentor is composed of multiple specialized repositories.  
This main repository serves as the **central hub**, while the following linked components handle data, ML training, and backend engine logic:

---

#### 📘 1. Dataset & Annotation (Roboflow)
- **Roboflow Workspace:**  
  https://universe.roboflow.com/chessmentor/chessmentor  

Contains all annotated chessboard datasets, preprocessing pipelines, and model versions used during training.

---

#### 🤖 2. Machine Learning Model (YOLOv11s Training)
- **ChessMentor-ML Repository:**  
  https://github.com/ObayAlshaer/ChessMentor-ML/tree/main  

Includes:
- Simulation notebooks 
- Data preprocessing   

---

#### ♟️ 3. Stockfish Evaluation API
- **Stockfish Flask API (Python):**  
  https://github.com/otoua046/stockfish-api  

Provides:
- REST endpoint for Stockfish best-move evaluation  
- Return format used by the iOS app  
- Engine configuration and depth settings  

---

###  High-Level Architecture

```text
          [iOS App UI]
                |
                v
     [Chessboard Scanner (Swift)]
                |
                v
      [Roboflow Inference API]
                |
                v
       [FEN Generator Logic]
                |
                v
     [Stockfish Flask API Server]
                |
                v
       [Best Move Suggestion]
```

## Features

- **Augmented Reality Chess Analysis**: Utilize AR technology to analyze chess positions in real-time.
- **Move Suggestions**: Receive intelligent move suggestions based on board positions and game analysis.
- **Camera Integration**: Seamlessly integrate your device's camera to capture and analyze chessboard positions.
- **User-Friendly Interface**: Enjoy a clean and intuitive interface designed for ease of use and accessibility.

## Usage

1. Launch the app and grant camera permissions when prompted.
2. Hold your device's camera above a chessboard with a game in progress.
3. Allow the app to analyze the board and suggest moves based on the current game state.
4. Review the suggested moves and make your decision accordingly.

## Acknowledgements

Special thanks to the contributors and maintainers of ARKit and SwiftUI for their valuable tools and frameworks.


## Author Information & Time spent

| Name                | Student Number | Time spent |        Email        |
|---------------------|----------------|------------|---------------------|
| Mohamed-Obay Alshaer | 300170489     |  100 hours  | malsh094@uottawa.ca |
| Sam Touahri         | 300234041      |  100 hours  | otoua046@uottawa.ca |
| Justin Bushfield    | 300188318      |  100 hours  | jbush023@uottawa.ca |
| Samuel Rose          | 300173591     |  100 hours  | srose096@uottawa.ca |
| Anas Hammou          | 300220367     |  100 hours  | ahamm073@uottawa.ca |

## Client Information 

| Name                | Affiliation    | Email                  |
|---------------------|----------------|------------------------|
|Omar Al-Dib          | CUSmile (Charity) | mromaldib@gmail.com    |

# ChessMentor – Inference Deployment Benchmark Study ♟️

This repository contains a systems-level evaluation of **on-device vs server-side computer vision inference** using the ChessMentor mobile chessboard recognition application as a case study.

This is a **separate academic benchmarking project** built on top of the original ChessMentor capstone application. The focus is not feature development, but rigorous measurement and analysis of machine learning deployment trade-offs.

---

## 🎯 Project Goal

To quantitatively compare:

- **Pipeline A:** On-device inference
- **Pipeline B:** Server-side (hosted API) inference

Across the following dimensions:

- End-to-end latency
- Inference time breakdown
- Network overhead
- Energy consumption
- Accuracy and failure modes

The objective is to determine practical trade-offs in real-world mobile ML deployment decisions.

---

## 🏗 Repository Structure

```
chessmentor-inference-benchmark/
│
├── chessMentor/          # Core mobile application logic
├── Views/                # UI components
├── benchmark/            # Benchmarking harness & measurement logic
├── server/               # Optional proxy / server components
├── report/               # Proposal & final report
├── docs/                 # Experiment configuration & methodology
```

---

## 🔬 Methodology Overview

- Frozen model version (Roboflow)
- Identical preprocessing across pipelines
- Controlled confidence thresholds
- Structured chessboard recognition workload
- Reproducible benchmark logging (CSV output)

All results are logged and analyzed externally to maintain separation between inference logic and evaluation metrics.

---

## 📦 Original ChessMentor Architecture (Reference)

The original application integrates:

- Roboflow vision inference
- Chessboard state extraction (FEN)
- Stockfish evaluation API

This repository extends that system with instrumentation and benchmarking infrastructure without altering core functionality.

---

## 📚 Academic Context

This project is conducted as part of a machine learning systems course. It evaluates deployment architecture decisions rather than model development.

---

## 👤 Author

Sam Touahri  
University of Ottawa  
Software Engineering