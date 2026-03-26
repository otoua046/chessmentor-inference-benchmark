import SwiftUI
import UIKit
import OSLog

private let vmLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "chessmentor",
                           category: "Analysis")

@MainActor
final class ResultsViewModel: ObservableObject {
    
    enum Phase {
        case idle
        case cropping
        case detecting
        case generatingFEN
        case queryingEngine
        case drawingArrow
        case done(AnalysisResult)
        case failed(String)
    }

    @Published var phase: Phase = .idle

    // Services
    private let cropper: BoardCropper
    private let pieceDetector: any PieceDetectionServing
    private let fenBuilder = FenBuilder()
    private let engine: StockfishService        // ← no default here
    private let drawer: ArrowDrawer 
    private let saveDebugImages: Bool           // ← no default here
    private let benchmarkLogger: BenchmarkLogger?

    init(cropper: BoardCropper,
         pieceDetector: any PieceDetectionServing,
         engine: StockfishService = StockfishService(),
         drawer: ArrowDrawer = ArrowDrawer(),
         saveDebugImages: Bool = true,
         benchmarkLogger: BenchmarkLogger? = nil) {

        self.cropper = cropper
        self.pieceDetector = pieceDetector
        self.engine  = engine
        self.drawer  = drawer
        self.saveDebugImages = saveDebugImages
        self.benchmarkLogger = benchmarkLogger
    }

    convenience init(
        roboflowApiKey: String,
        pipelineMode: PipelineMode = .hosted,
        pieceModelId: String = InferenceFactory.defaultPieceModelId,
        boardModelId: String = InferenceFactory.defaultBoardModelId,
        confidence: Double = InferenceFactory.defaultPieceConfidence,
        overlap: Double = InferenceFactory.defaultPieceOverlap
    ) {
        let factory = InferenceFactory(
            mode: pipelineMode,
            roboflowApiKey: roboflowApiKey,
            pieceModelId: pieceModelId,
            boardModelId: boardModelId,
            pieceConfidence: confidence,
            pieceOverlap: overlap
        )
        self.init(
            cropper: factory.makeBoardCropper(),
            pieceDetector: factory.makePieceDetector(),
            benchmarkLogger: factory.makeBenchmarkLogger()
        )
    }

    struct BenchmarkRunResult {
        let inputID: String
        let success: Bool
        let detectionCount: Int?
        let fenValid: Bool?
        let errorMessage: String?
    }

    private struct PhotoPipelineSuccess {
        let cropped: UIImage
        let predictions: [Prediction]
        let fen: String
    }

    private struct PhotoPipelineFailure {
        let benchmarkResult: BenchmarkRunResult
        let userMessage: String
    }

    private enum PhotoPipelineOutcome {
        case success(PhotoPipelineSuccess)
        case failure(PhotoPipelineFailure)
    }


    func run(with image: UIImage) {
        Task {
            vmLog.info("Analysis start")

            switch await runPhotoPipeline(
                with: image,
                inputID: "photo-\(UUID().uuidString)",
                updatesPhase: true
            ) {
            case .success(let success):
                do {
                    phase = .queryingEngine
                    let best = try await engine.bestMove(for: success.fen)
                    vmLog.info("Engine OK: UCI \(best.best_move_uci, privacy: .public) / SAN \(best.best_move_san, privacy: .public)")

                    phase = .drawingArrow
                    let final = drawer.draw(on: success.cropped, uci: best.best_move_uci)

                    let overlays = drawDetections(on: success.cropped, predictions: success.predictions)
                    phase = .done(.init(cropped: success.cropped,
                                        overlays: overlays,
                                        fen: success.fen,
                                        bestMove: best,
                                        finalImage: final))
                    vmLog.info("Analysis done")
                } catch {
                    let msg = localizedMessage(for: error)
                    vmLog.error("Analysis failed: \(msg, privacy: .public)")
                    phase = .failed(msg)
                }
            case .failure(let failure):
                vmLog.error("Analysis failed: \(failure.userMessage, privacy: .public)")
                phase = .failed(failure.userMessage)
            }
        }
    }

    func runBenchmark(with image: UIImage, inputID: String) async -> BenchmarkRunResult {
        vmLog.info("Benchmark analysis start: \(inputID, privacy: .public)")

        switch await runPhotoPipeline(
            with: image,
            inputID: inputID,
            updatesPhase: false
        ) {
        case .success(let success):
            return BenchmarkRunResult(
                inputID: inputID,
                success: true,
                detectionCount: success.predictions.count,
                fenValid: true,
                errorMessage: nil
            )
        case .failure(let failure):
            return failure.benchmarkResult
        }
    }

    private func runPhotoPipeline(
        with image: UIImage,
        inputID: String,
        updatesPhase: Bool
    ) async -> PhotoPipelineOutcome {
        let benchmarkSession = benchmarkLogger?.startPhotoRun(inputID: inputID)

        setPhase(.cropping, enabled: updatesPhase)
        let boardStartedAt = ProcessInfo.processInfo.systemUptime
        let cropped: UIImage
        do {
            cropped = try cropper.crop(image)
            benchmarkSession?.markBoardCompleted(
                ms: elapsedMilliseconds(since: boardStartedAt)
            )
        } catch {
            let msg = localizedMessage(for: error)
            return .failure(
                finishFailure(
                    inputID: inputID,
                    userMessage: msg,
                    errorMessage: "board_crop_failed: \(msg)",
                    benchmarkSession: benchmarkSession
                )
            )
        }

        if saveDebugImages {
            PhotoSaver.saveToLibrary(cropped)
            vmLog.info("Saved cropped board to Photos.")
        }

        setPhase(.detecting, enabled: updatesPhase)
        let pieceStartedAt = ProcessInfo.processInfo.systemUptime
        let raw: [Prediction]
        do {
            raw = try await pieceDetector.detect(on: cropped)
            benchmarkSession?.markPieceCompleted(
                ms: elapsedMilliseconds(since: pieceStartedAt)
            )
        } catch {
            let msg = localizedMessage(for: error)
            return .failure(
                finishFailure(
                    inputID: inputID,
                    userMessage: msg,
                    errorMessage: "piece_detection_failed: \(msg)",
                    benchmarkSession: benchmarkSession
                )
            )
        }
        vmLog.info("Raw detections: \(raw.count, privacy: .public)")

        let filter = PieceFilter(
            minConfidence: 0.30,
            minConfidenceKing: 0.22,
            edgeTrimSquares: 0.12,
            minSizeFrac: 0.35,
            maxSizeFrac: 1.60
        )
        let preds = filter.apply(raw, imageSize: cropped.size)
        vmLog.info("Filtered detections: \(preds.count, privacy: .public)")

        if saveDebugImages,
           let rawPreview = drawDetectionPreview(on: cropped, predictions: raw) {
            PhotoSaver.saveToLibrary(rawPreview)
        }
        if saveDebugImages,
           let filteredPreview = drawDetectionPreview(on: cropped, predictions: preds) {
            PhotoSaver.saveToLibrary(filteredPreview)
        }

        let grouped = Dictionary(grouping: preds, by: { $0.class })
            .map { "\($0.key): \($0.value.count)" }
            .sorted()
        vmLog.info("Class breakdown (filtered) → \(grouped.joined(separator: ", "), privacy: .public)")

        setPhase(.generatingFEN, enabled: updatesPhase)
        let fen = fenBuilder.fen(from: preds, imageSize: cropped.size)
        vmLog.debug("FEN \(fen, privacy: .public)")

        let check = FENValidator().isLikelyValid(fen)
        guard check.ok else {
            let reason = check.reason ?? "invalid FEN"
            vmLog.error("Invalid FEN: \(reason, privacy: .public)")
            return .failure(
                finishFailure(
                    inputID: inputID,
                    userMessage: """
                    Board detection looks incomplete (\(reason)).
                    Try a clearer photo with the full board visible.
                    """,
                    detectionCount: preds.count,
                    fenValid: false,
                    errorMessage: "invalid_fen: \(reason)",
                    benchmarkSession: benchmarkSession
                )
            )
        }

        benchmarkSession?.finishSuccess(
            detectionCount: preds.count,
            fenValid: true
        )

        return .success(
            PhotoPipelineSuccess(
                cropped: cropped,
                predictions: preds,
                fen: fen
            )
        )
    }

    private func finishFailure(
        inputID: String,
        userMessage: String,
        detectionCount: Int? = nil,
        fenValid: Bool? = nil,
        errorMessage: String,
        benchmarkSession: BenchmarkSession?
    ) -> PhotoPipelineFailure {
        benchmarkSession?.finishFailure(
            detectionCount: detectionCount,
            fenValid: fenValid,
            errorMessage: errorMessage
        )
        return PhotoPipelineFailure(
            benchmarkResult: BenchmarkRunResult(
                inputID: inputID,
                success: false,
                detectionCount: detectionCount,
                fenValid: fenValid,
                errorMessage: errorMessage
            ),
            userMessage: userMessage
        )
    }

    private func setPhase(_ phase: Phase, enabled: Bool) {
        guard enabled else { return }
        self.phase = phase
    }

    private func elapsedMilliseconds(since start: TimeInterval) -> Double {
        (ProcessInfo.processInfo.systemUptime - start) * 1000
    }

    private func localizedMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: - Helpers

    /// Simple boxes-only overlay (used inside UI if you want to show it)
    private func drawDetections(on image: UIImage, predictions: [Prediction]) -> UIImage? {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))
            let cg = ctx.cgContext
            cg.setLineWidth(2)
            cg.setStrokeColor(UIColor.systemGreen.cgColor)
            for p in predictions {
                let rect = CGRect(x: p.x - p.width/2,
                                  y: p.y - p.height/2,
                                  width: p.width, height: p.height)
                cg.stroke(rect)
            }
        }
    }

    /// DEBUG preview: grid + boxes + labels (+ confidence)
    private func drawDetectionPreview(on image: UIImage, predictions: [Prediction]) -> UIImage? {
        let size = image.size
        let SQUARE = size.width / 8
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))
            let cg = ctx.cgContext

            // 8×8 grid
            cg.setLineWidth(1)
            cg.setStrokeColor(UIColor.systemGray.withAlphaComponent(0.6).cgColor)
            for i in 1..<8 {
                let x = CGFloat(i) * SQUARE
                let y = CGFloat(i) * SQUARE
                cg.move(to: CGPoint(x: x, y: 0));              cg.addLine(to: CGPoint(x: x, y: size.height))
                cg.move(to: CGPoint(x: 0, y: y));              cg.addLine(to: CGPoint(x: size.width, y: y))
            }
            cg.strokePath()

            // boxes
            cg.setLineWidth(2)
            cg.setStrokeColor(UIColor.systemGreen.cgColor)

            for p in predictions {
                let rect = CGRect(x: p.x - p.width/2,
                                  y: p.y - p.height/2,
                                  width: p.width, height: p.height)
                cg.stroke(rect)

                // label
                let label: String
                if let c = p.confidence {
                    label = "\(p.class)  \(String(format: "%.2f", Double(c)))"
                } else {
                    label = p.class
                }

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.white,
                    .backgroundColor: UIColor.black.withAlphaComponent(0.65)
                ]
                let ns = label as NSString
                let sz = ns.size(withAttributes: attrs)
                let labelRect = CGRect(x: rect.minX,
                                       y: max(0, rect.minY - sz.height - 2),
                                       width: sz.width, height: sz.height)
                ns.draw(in: labelRect, withAttributes: attrs)
            }
        }
    }
}

// MARK: - AnalysisResult (defined in Models.swift)
