import Foundation
import CoreMedia
import QuartzCore
import UIKit

/// View model for live, on-camera chessboard analysis.
/// Handles frame throttling, board detection, engine queries, UI status updates,
/// and arrow overlay data computation. Must run on the main actor because it updates @Published properties.
@MainActor
final class LiveAnalysisViewModel: ObservableObject {

    /// Component responsible for detecting a chessboard and computing a FEN from camera frames.
    private let detector: BoardDetector

    /// Component that queries a chess engine to compute a best move given a FEN.
    private let engine: BestMoveProvider

    /// Latest detected FEN string from the camera, if any.
    @Published var currentFEN: String?

    /// UI-friendly representation of best move (SAN preferred, falling back to UCI).
    @Published var bestMoveDisplay: String?

    /// Engine evaluation formatted as a display string such as "+1.23".
    @Published var evaluationText: String?

    /// Human-readable processing state (e.g. "Searching", "Live", errors).
    @Published var status: String = "Searching for board…"

    /// Whether a frame is currently being analyzed to prevent overlapping detection tasks.
    @Published var isAnalyzing: Bool = false

    /// Arrow overlay data for drawing a move indicator on live preview. Nil when no arrow should be shown.
    @Published var liveArrow: LiveArrow?

    /// Timestamp of last processed frame to enforce throttling.
    private var lastAt: TimeInterval = 0

    /// Minimum time interval between frame analyses. Prevents overwhelming CPU or engine usage.
    private let minInterval: TimeInterval = 0.8

    /// Handle to the currently running analysis task (for cancellation).
    private var task: Task<Void, Never>?

    /// Initializes live analyzer with required board detection and engine components.
    init(detector: BoardDetector, engine: BestMoveProvider) {
        self.detector = detector
        self.engine = engine
    }

    /// Ingests a camera frame (pixel buffer), throttles processing, launches async board detection
    /// and best-move analysis, and publishes UI state updates.
    func handleFrame(_ pixelBuffer: CVPixelBuffer) {
        let now = CACurrentMediaTime()

        // Skip frames if analysis is already running or the throttle interval has not elapsed yet.
        guard !isAnalyzing, (now - lastAt) >= minInterval else { return }
        lastAt = now
        isAnalyzing = true

        // Cancel the previous task so stale analysis work does not pile up.
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                // Attempt board detection from the current camera frame.
                guard let board = try detector.detect(from: pixelBuffer) else {
                    status = "No board found"
                    isAnalyzing = false
                    liveArrow = nil
                    return
                }

                currentFEN = board.fen
                status = "Analyzing…"

                // Request the best move from the engine for the detected FEN.
                let res = try await engine.bestMove(for: board.fen)

                // Prefer SAN for display; fall back to UCI when SAN is unavailable.
                bestMoveDisplay = res.san.isEmpty ? res.uci : res.san

                // Convert the engine evaluation to a formatted text value such as "+0.45".
                evaluationText = res.evaluation.map { String(format: "%+.2f", $0) }

                status = "Live"

                // Compute arrow endpoints in cropped board coordinates (typically 800×800).
                if let (p1, p2) = centers(forUCI: res.uci, boardSize: board.cropped.size) {
                    liveArrow = LiveArrow(
                        sourceSize: board.sourcePixelSize,
                        cropRect: board.cropRectInSource,
                        boardSize: board.cropped.size,
                        p1Cropped: p1,
                        p2Cropped: p2
                    )
                } else {
                    liveArrow = nil
                }
            } catch {
                // Surface detection or engine failures to the on-screen status.
                status = "Error: \(error.localizedDescription)"
                liveArrow = nil
            }
            isAnalyzing = false
        }
    }

    /// Cancels ongoing analysis task, useful when view disappears or app stops camera.
    func cancel() {
        task?.cancel()
        task = nil
    }

    /// Converts a UCI move into a pair of geometric center points for arrow drawing.
    /// Each square is mapped to the center of an 8×8 grid within a given board size.
    private func centers(forUCI uci: String, boardSize: CGSize) -> (CGPoint, CGPoint)? {
        guard uci.count >= 4 else { return nil }

        // Source square (e.g. "e2") and destination square (e.g. "e4").
        let src = String(uci.prefix(2))
        let dst = String(uci.dropFirst(2).prefix(2))

        /// Computes the visual center of a chess square (0-7 file, 1-8 rank).
        func center(of square: String, size: CGSize) -> CGPoint {
            let fileChar = square.first!
            let rankChar = square.last!

            // Convert file letter a-h to a 0-7 integer.
            let file = Int(fileChar.asciiValue! - Character("a").asciiValue!) // 0..7

            // Convert the rank character 1-8 directly to an Int.
            let rank = Int(String(rankChar))!                                  // 1..8

            // Compute square size and translate it to the square center.
            let sq = size.width / 8.0
            let x = (CGFloat(file) + 0.5) * sq
            let y = (CGFloat(8 - rank) + 0.5) * sq
            return CGPoint(x: x, y: y)
        }

        return (center(of: src, size: boardSize),
                center(of: dst, size: boardSize))
    }
}
