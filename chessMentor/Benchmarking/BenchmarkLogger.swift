import Foundation

final class BenchmarkLogger {
    private static let writeQueue = DispatchQueue(label: "chessmentor.benchmark.logger")

    private let config: BenchmarkConfig

    init(config: BenchmarkConfig) {
        self.config = config
    }

    func startPhotoRun(inputID: String) -> BenchmarkSession? {
        guard config.isEnabled else { return nil }
        return BenchmarkSession(
            logger: self,
            config: config,
            flowType: .photo,
            inputID: inputID
        )
    }

    func append(_ record: BenchmarkRecord) {
        guard config.isEnabled else { return }

        Self.writeQueue.sync {
            ensureOutputFileExists()

            guard let data = (record.csvLine + "\n").data(using: .utf8) else { return }
            do {
                let handle = try FileHandle(forWritingTo: config.outputURL)
                defer { handle.closeFile() }
                handle.seekToEndOfFile()
                handle.write(data)
            } catch {
                assertionFailure("Failed to append benchmark CSV row: \(error)")
            }
        }
    }

    private func ensureOutputFileExists() {
        let fileManager = FileManager.default
        let directory = config.outputURL.deletingLastPathComponent()

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            assertionFailure("Failed to create benchmark directory: \(error)")
            return
        }

        guard !fileManager.fileExists(atPath: config.outputURL.path) else { return }

        do {
            try (BenchmarkRecord.headerLine + "\n").write(
                to: config.outputURL,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            assertionFailure("Failed to create benchmark CSV file: \(error)")
        }
    }
}

final class BenchmarkSession {
    private let logger: BenchmarkLogger
    private let config: BenchmarkConfig
    private let flowType: BenchmarkFlowType
    private let inputID: String
    private let timestamp: Date
    private let startedAt: TimeInterval

    private var boardMS: Double?
    private var pieceMS: Double?
    private var detectionCount: Int?
    private var fenValid: Bool?
    private var finished = false

    fileprivate init(
        logger: BenchmarkLogger,
        config: BenchmarkConfig,
        flowType: BenchmarkFlowType,
        inputID: String
    ) {
        self.logger = logger
        self.config = config
        self.flowType = flowType
        self.inputID = inputID
        self.timestamp = Date()
        self.startedAt = ProcessInfo.processInfo.systemUptime
    }

    func markBoardCompleted(ms: Double) {
        guard !finished else { return }
        boardMS = ms
    }

    func markPieceCompleted(ms: Double) {
        guard !finished else { return }
        pieceMS = ms
    }

    func finishSuccess(detectionCount: Int, fenValid: Bool) {
        finish(
            detectionCount: detectionCount,
            fenValid: fenValid,
            success: true,
            errorMessage: nil
        )
    }

    func finishFailure(
        detectionCount: Int? = nil,
        fenValid: Bool? = nil,
        errorMessage: String
    ) {
        finish(
            detectionCount: detectionCount,
            fenValid: fenValid,
            success: false,
            errorMessage: errorMessage
        )
    }

    private func finish(
        detectionCount: Int?,
        fenValid: Bool?,
        success: Bool,
        errorMessage: String?
    ) {
        guard !finished else { return }
        finished = true
        self.detectionCount = detectionCount
        self.fenValid = fenValid

        let record = BenchmarkRecord(
            timestamp: timestamp,
            sessionID: config.sessionID,
            device: BenchmarkRecord.currentDeviceDescription,
            pipelineMode: config.pipelineMode.rawValue,
            flowType: flowType.rawValue,
            inputID: inputID,
            boardBackend: config.boardBackend,
            pieceBackend: config.pieceBackend,
            boardMS: boardMS,
            pieceMS: pieceMS,
            totalMS: elapsedMilliseconds(since: startedAt),
            detectionCount: self.detectionCount,
            fenValid: self.fenValid,
            success: success,
            errorMessage: Self.normalizedErrorMessage(errorMessage)
        )

        logger.append(record)
    }

    private func elapsedMilliseconds(since start: TimeInterval) -> Double {
        (ProcessInfo.processInfo.systemUptime - start) * 1000
    }

    private static func normalizedErrorMessage(_ errorMessage: String?) -> String? {
        guard let errorMessage else { return nil }
        let collapsed = errorMessage
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? nil : collapsed
    }
}
