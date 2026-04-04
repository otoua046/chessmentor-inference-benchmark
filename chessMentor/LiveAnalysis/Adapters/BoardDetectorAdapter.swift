import CoreMedia
import CoreImage
import UIKit
import OSLog

/// Adapter responsible for orchestrating the end-to-end chessboard detection process:
/// 1. Crop the board from the input image
/// 2. Detect individual pieces using a Roboflow model
/// 3. Filter noisy predictions
/// 4. Convert predictions to FEN
/// 5. Validate the resulting chess position
///
/// Implements the `BoardDetector` protocol so this can be swapped in production,
/// testing, or mocked environments.
struct BoardDetectorAdapter: BoardDetector {

    /// Logger instance used for runtime board detection events.
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "chessmentor",
        category: "LiveBoardDetector"
    )

    /// Crops the original image to an isolated chessboard region based on ML detection.
    private let cropper: BoardCropper

    /// Piece detector used for object detection on the cropped board image.
    private let pieceDetector: any PieceDetectionServing

    /// Builds FEN strings from filtered piece predictions.
    private let fenBuilder = FenBuilder()

    /// Performs structural validity checks on generated FEN (e.g., both kings exist).
    private let validator = FENValidator()

    /// Applies heuristics to remove low-confidence or invalid piece detections.
    private let filter: PieceFilter

    init(
        cropper: BoardCropper,
        pieceDetector: any PieceDetectionServing,
        filter: PieceFilter = PieceFilter(
            minConfidence: 0.30,
            minConfidenceKing: 0.22,
            edgeTrimSquares: 0.12,
            minSizeFrac: 0.35,
            maxSizeFrac: 1.60
        )
    ) {
        self.cropper = cropper
        self.pieceDetector = pieceDetector
        self.filter = filter
    }

    init(
        roboflowApiKey: String,
        pieceModelId: String = InferenceFactory.defaultPieceModelId,
        boardModelId: String = InferenceFactory.defaultBoardModelId,
        pipelineMode: PipelineMode = .hosted
    ) {
        let factory = InferenceFactory(
            mode: pipelineMode,
            roboflowApiKey: roboflowApiKey,
            pieceModelId: pieceModelId,
            boardModelId: boardModelId
        )
        self.cropper = factory.makeBoardCropper()
        self.pieceDetector = factory.makePieceDetector()
        self.filter = PieceFilter(
            minConfidence: 0.30,
            minConfidenceKing: 0.22,
            edgeTrimSquares: 0.12,
            minSizeFrac: 0.35,
            maxSizeFrac: 1.60
        )
    }

    /// Primary detection pipeline.
    ///
    /// - Converts a CVPixelBuffer (camera frame) to UIImage
    /// - Crops the board region from the source
    /// - Detects raw piece predictions using ML
    /// - Filters predictions and constructs a candidate FEN string
    /// - Validates the FEN; returns `nil` for unlikely/invalid positions
    ///
    /// Throws on Roboflow network or processing errors.
    func detect(from pixelBuffer: CVPixelBuffer) throws -> DetectedBoard? {
        guard let uiImage = UIImage(pixelBuffer: pixelBuffer) else { return nil }

        // 1) Detect and crop the chessboard, keeping track of scaling so we can map
        //    predictions back into original image coordinates.
        let r = try cropper.cropWithRect(uiImage) // returns 800x800 + cropRect + sourceSize

        // 2) Detect raw predictions of chess pieces on the cropped 800×800 image.
        let raw = try awaitDetectPieces(on: r.cropped)
        if raw.isEmpty { return nil }

        // 3) Clean up detections and build a FEN representation.
        let preds = filter.apply(raw, imageSize: r.cropped.size)
        let fen = fenBuilder.fen(from: preds, imageSize: r.cropped.size)

        // Validate board structure (e.g., king count, square occupancy sanity).
        let check = validator.isLikelyValid(fen)
        guard check.ok else { return nil }

        // Construct the final FEN result together with crop metadata used by overlays.
        return DetectedBoard(
            fen: fen,
            cropped: r.cropped,
            cropRectInSource: r.rectInSource,
            sourcePixelSize: r.sourceSize
        )
    }

    /// Executes Roboflow piece detection using an async API, but exposes a synchronous
    /// interface by blocking with a semaphore. Useful when caller cannot be async.
    ///
    /// Wraps `pieceDetector.detect(on:)` using `Task` and bridges back to synchronous code.
    private func awaitDetectPieces(on image: UIImage) throws -> [Prediction] {
        var out: Result<[Prediction], Error>!
        let sem = DispatchSemaphore(value: 0)

        // Launch the asynchronous detection task, then block until completion.
        Task {
            do {
                Self.log.info("Live piece detection start")
                let predictions = try await pieceDetector.detect(on: image)
                Self.log.info("Live piece detection OK. predictions=\(predictions.count, privacy: .public)")
                out = .success(predictions)
            }
            catch { out = .failure(error) }
            sem.signal()
        }

        // Block thread until detection completes
        sem.wait()

        // Convert the captured Result into either a return value or a thrown error.
        switch out! {
        case .success(let p): return p
        case .failure(let e): throw e
        }
    }

}

// MARK: - CVPixelBuffer Conversion

/// Converts a camera pixel buffer (`CVPixelBuffer`) into a standard UIImage using Core Image.
/// Used to feed live camera frames into ML detection routines.
private extension UIImage {
    /// Initializes a UIImage from a CVPixelBuffer by rendering it through a Core Image context.
    convenience init?(pixelBuffer: CVPixelBuffer) {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let ctx = CIContext(options: nil)
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        self.init(cgImage: cg)
    }
}
