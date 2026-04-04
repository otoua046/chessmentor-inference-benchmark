import CoreMedia
import UIKit

/// Represents the output of a successful chessboard detection pipeline.
/// Contains FEN, a cropped board image, and information needed to map
/// cropped coordinates back to the original camera/source frame.
public struct DetectedBoard: Equatable {

    /// FEN string describing the detected chess position.
    public let fen: String

    /// Cropped 800×800 image of the board used for piece detection and visualization.
    public let cropped: UIImage              // 800x800

    /// Location of the cropped board region in the original camera frame (used for drawing overlays).
    public let cropRectInSource: CGRect      // in source image coords

    /// Full resolution of the source image from which the board was extracted.
    public let sourcePixelSize: CGSize       // source image size used by cropper

    /// Initializes a detected board result with mapping metadata for UI overlays and analysis.
    public init(
        fen: String,
        cropped: UIImage,
        cropRectInSource: CGRect,
        sourcePixelSize: CGSize
    ) {
        self.fen = fen
        self.cropped = cropped
        self.cropRectInSource = cropRectInSource
        self.sourcePixelSize = sourcePixelSize
    }
}

/// Represents the output of a chess engine evaluation request (Stockfish or similar).
/// Includes best move in both UCI and SAN formats plus optional evaluation score
/// and principal variation (PV).
public struct EngineResult: Equatable {

    /// Best move in UCI notation (e.g., "e2e4").
    public let uci: String

    /// Best move in SAN notation (e.g., "Nf3").
    public let san: String

    /// Numerical evaluation of the position from the engine (positive for white, negative for black).
    public let evaluation: Double?

    /// Optional principal variation (engine's suggested continuation sequence).
    public let pv: [String]?

    /// Initializes a result wrapper for engine output data.
    public init(
        uci: String,
        san: String,
        evaluation: Double?,
        pv: [String]?
    ) {
        self.uci = uci
        self.san = san
        self.evaluation = evaluation
        self.pv = pv
    }
}

/// Protocol defining a component capable of detecting chessboard positions
/// from camera pixel buffers. Returns optional `DetectedBoard` to allow
/// early exit when no valid board is found.
public protocol BoardDetector {
    func detect(from pixelBuffer: CVPixelBuffer) throws -> DetectedBoard?
}

/// Protocol defining a chess engine query service.
/// Consumes a FEN string and produces a best move result asynchronously.
public protocol BestMoveProvider {
    func bestMove(for fen: String) async throws -> EngineResult
}

/// Container for all data needed to draw a move arrow overlay on top of
/// a live camera preview. Includes mapping between cropped and full-frame
/// coordinates and endpoints of the arrow.
public struct LiveArrow {

    /// Full camera frame resolution being displayed.
    public let sourceSize: CGSize           // full camera frame size used by preview

    /// Rectangle where the detected board is located in the full camera frame.
    public let cropRect: CGRect             // where the board lives in that frame

    /// Pixel size of the cropped board image (typically a square like 800×800).
    public let boardSize: CGSize            // cropped board size (usually 800x800)

    /// Starting point of arrow (piece location) in cropped image coordinate system.
    public let p1Cropped: CGPoint           // arrow start in cropped coords

    /// Ending point of arrow (destination square) in cropped image coordinate system.
    public let p2Cropped: CGPoint           // arrow end in cropped coords
}
