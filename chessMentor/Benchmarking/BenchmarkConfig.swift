import Foundation

struct BenchmarkConfig {
    static let processSessionID = UUID().uuidString
    static let outputFileName = "benchmark_runs.csv"

    let isEnabled: Bool
    let sessionID: String
    let pipelineMode: PipelineMode
    let boardBackend: String
    let pieceBackend: String
    let outputURL: URL

    init(
        pipelineMode: PipelineMode,
        boardBackend: String,
        pieceBackend: String,
        enabledOverride: Bool? = nil,
        outputURL: URL? = nil,
        sessionID: String = Self.processSessionID,
        processInfo: ProcessInfo = .processInfo,
        fileManager: FileManager = .default
    ) {
        self.isEnabled = enabledOverride ?? Self.loggingEnabled(processInfo: processInfo)
        self.sessionID = sessionID
        self.pipelineMode = pipelineMode
        self.boardBackend = boardBackend
        self.pieceBackend = pieceBackend
        self.outputURL = outputURL ?? Self.defaultOutputURL(fileManager: fileManager)
    }

    static func loggingEnabled(processInfo: ProcessInfo = .processInfo) -> Bool {
        // CSV logging stays opt-in so normal app runs do not emit benchmark records.
        processInfo.arguments.contains("ENABLE_BENCHMARK_LOGGING")
            || processInfo.environment["ENABLE_BENCHMARK_LOGGING"] == "1"
    }

    static func defaultOutputURL(fileManager: FileManager = .default) -> URL {
        defaultOutputURL(fileName: outputFileName, fileManager: fileManager)
    }

    static func defaultOutputURL(
        fileName: String,
        fileManager: FileManager = .default
    ) -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return documentsDirectory.appendingPathComponent(fileName)
    }
}
