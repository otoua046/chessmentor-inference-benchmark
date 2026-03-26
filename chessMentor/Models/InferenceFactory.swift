import Foundation

enum PipelineMode: String, CaseIterable {
    case hosted
    case local

    init(configurationValue: String?) {
        guard let normalized = configurationValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            let mode = PipelineMode(rawValue: normalized)
        else {
            self = .hosted
            return
        }

        self = mode
    }

    init?(overrideValue: String?) {
        guard let normalized = overrideValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            let mode = PipelineMode(rawValue: normalized)
        else {
            return nil
        }

        self = mode
    }

    var displayName: String {
        switch self {
        case .hosted:
            return "Hosted"
        case .local:
            return "Local"
        }
    }
}

struct InferenceFactory {
    static let defaultPieceModelId = "chessmentor/8"
    static let defaultBoardModelId = hostedBoardCropperModelId
    static let defaultPieceConfidence = 0.30
    static let defaultPieceOverlap = 0.50
    static let defaultBoardConfidence = 0.25
    static let defaultBoardOverlap = 0.20

    let mode: PipelineMode
    let roboflowApiKey: String
    let pieceModelId: String
    let boardModelId: String
    let pieceConfidence: Double
    let pieceOverlap: Double
    let boardConfidence: Double
    let boardOverlap: Double

    init(
        mode: PipelineMode,
        roboflowApiKey: String,
        pieceModelId: String = Self.defaultPieceModelId,
        boardModelId: String = Self.defaultBoardModelId,
        pieceConfidence: Double = Self.defaultPieceConfidence,
        pieceOverlap: Double = Self.defaultPieceOverlap,
        boardConfidence: Double = Self.defaultBoardConfidence,
        boardOverlap: Double = Self.defaultBoardOverlap
    ) {
        self.mode = mode
        self.roboflowApiKey = roboflowApiKey
        self.pieceModelId = pieceModelId
        self.boardModelId = boardModelId
        self.pieceConfidence = pieceConfidence
        self.pieceOverlap = pieceOverlap
        self.boardConfidence = boardConfidence
        self.boardOverlap = boardOverlap
    }

    func makeBoardDetector() -> any BoardDetectionServing {
        switch mode {
        case .hosted:
            return RoboflowClient(
                apiKey: roboflowApiKey,
                modelId: boardModelId,
                confidence: boardConfidence,
                overlap: boardOverlap
            )
        case .local:
            return RoboflowOnDeviceBoardCropInferenceService(
                apiKey: roboflowApiKey,
                modelId: boardModelId,
                confidence: boardConfidence,
                overlap: boardOverlap
            )
        }
    }

    func makeBoardCropper() -> BoardCropper {
        BoardCropper(
            detector: makeBoardDetector(),
            boardModelId: boardModelId,
            maxLongSide: 1280,
            padFrac: 0.03,
            enforceSquare: true
        )
    }

    func makePieceDetector() -> any PieceDetectionServing {
        switch mode {
        case .hosted:
            return RoboflowClient(
                apiKey: roboflowApiKey,
                modelId: pieceModelId,
                confidence: pieceConfidence,
                overlap: pieceOverlap
            )
        case .local:
            return RoboflowOnDevicePieceInferenceService(
                apiKey: roboflowApiKey,
                modelId: pieceModelId,
                confidence: pieceConfidence,
                overlap: pieceOverlap
            )
        }
    }

    @MainActor
    func makeResultsViewModel() -> ResultsViewModel {
        ResultsViewModel(
            cropper: makeBoardCropper(),
            pieceDetector: makePieceDetector(),
            benchmarkLogger: makeBenchmarkLogger()
        )
    }

    func makeBoardDetectorAdapter() -> BoardDetectorAdapter {
        BoardDetectorAdapter(
            cropper: makeBoardCropper(),
            pieceDetector: makePieceDetector()
        )
    }

    func makeBenchmarkConfig(
        enabledOverride: Bool? = nil,
        outputURL: URL? = nil,
        sessionID: String = BenchmarkConfig.processSessionID
    ) -> BenchmarkConfig {
        BenchmarkConfig(
            pipelineMode: mode,
            boardBackend: boardBackendLabel,
            pieceBackend: pieceBackendLabel,
            enabledOverride: enabledOverride,
            outputURL: outputURL,
            sessionID: sessionID
        )
    }

    func makeBenchmarkLogger(
        enabledOverride: Bool? = nil,
        outputURL: URL? = nil,
        sessionID: String = BenchmarkConfig.processSessionID
    ) -> BenchmarkLogger? {
        let config = makeBenchmarkConfig(
            enabledOverride: enabledOverride,
            outputURL: outputURL,
            sessionID: sessionID
        )
        guard config.isEnabled else { return nil }
        return BenchmarkLogger(config: config)
    }

    @MainActor
    func makeBenchmarkResultsViewModel(
        outputURL: URL,
        sessionID: String
    ) -> ResultsViewModel {
        ResultsViewModel(
            cropper: makeBoardCropper(),
            pieceDetector: makePieceDetector(),
            saveDebugImages: false,
            benchmarkLogger: makeBenchmarkLogger(
                enabledOverride: true,
                outputURL: outputURL,
                sessionID: sessionID
            )
        )
    }

    private var boardBackendLabel: String {
        switch mode {
        case .hosted:
            return "hosted_roboflow_api"
        case .local:
            return "local_roboflow_mobile"
        }
    }

    private var pieceBackendLabel: String {
        switch mode {
        case .hosted:
            return "hosted_roboflow_api"
        case .local:
            return "local_roboflow_mobile"
        }
    }
}
