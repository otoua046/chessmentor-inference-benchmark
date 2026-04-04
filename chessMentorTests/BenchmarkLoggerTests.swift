import XCTest
@testable import chessMentor

final class BenchmarkLoggerTests: XCTestCase {

    func testBenchmarkConfigUsesProvidedOutputURLWhenEnabled() {
        let outputURL = temporaryCSVURL()
        let config = BenchmarkConfig(
            pipelineMode: .hosted,
            boardBackend: "hosted_roboflow_api",
            pieceBackend: "hosted_roboflow_api",
            enabledOverride: true,
            outputURL: outputURL,
            sessionID: "session-123"
        )

        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.outputURL, outputURL)
        XCTAssertEqual(config.sessionID, "session-123")
    }

    func testAppendWritesHeaderOnceAndKeepsSessionIDStable() throws {
        let outputURL = temporaryCSVURL()
        let config = BenchmarkConfig(
            pipelineMode: .hosted,
            boardBackend: "hosted_roboflow_api",
            pieceBackend: "hosted_roboflow_api",
            enabledOverride: true,
            outputURL: outputURL,
            sessionID: "session-123"
        )
        let logger = BenchmarkLogger(config: config)

        logger.append(
            BenchmarkRecord(
                timestamp: Date(timeIntervalSince1970: 1),
                sessionID: config.sessionID,
                device: "test-device",
                pipelineMode: config.pipelineMode.rawValue,
                flowType: BenchmarkFlowType.photo.rawValue,
                inputID: "photo-1",
                boardBackend: config.boardBackend,
                pieceBackend: config.pieceBackend,
                boardMS: 11.111,
                pieceMS: 22.222,
                totalMS: 33.333,
                detectionCount: 12,
                fenValid: true,
                success: true,
                errorMessage: nil
            )
        )
        logger.append(
            BenchmarkRecord(
                timestamp: Date(timeIntervalSince1970: 2),
                sessionID: config.sessionID,
                device: "test-device",
                pipelineMode: config.pipelineMode.rawValue,
                flowType: BenchmarkFlowType.photo.rawValue,
                inputID: "photo-2",
                boardBackend: config.boardBackend,
                pieceBackend: config.pieceBackend,
                boardMS: 44.444,
                pieceMS: 55.555,
                totalMS: 66.666,
                detectionCount: 13,
                fenValid: false,
                success: false,
                errorMessage: "invalid_fen: missing king"
            )
        )

        let lines = try readCSVLines(at: outputURL)
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], BenchmarkRecord.headerLine)
        XCTAssertTrue(lines[1].contains(",session-123,"))
        XCTAssertTrue(lines[2].contains(",session-123,"))
        XCTAssertTrue(lines[2].contains("invalid_fen: missing king"))
    }

    func testAppendEscapesCommaQuotesAndNewlines() throws {
        let outputURL = temporaryCSVURL()
        let config = BenchmarkConfig(
            pipelineMode: .hosted,
            boardBackend: "hosted_roboflow_api",
            pieceBackend: "hosted_roboflow_api",
            enabledOverride: true,
            outputURL: outputURL,
            sessionID: "session-escape"
        )
        let logger = BenchmarkLogger(config: config)

        logger.append(
            BenchmarkRecord(
                timestamp: Date(timeIntervalSince1970: 1),
                sessionID: config.sessionID,
                device: "test-device",
                pipelineMode: config.pipelineMode.rawValue,
                flowType: BenchmarkFlowType.photo.rawValue,
                inputID: "photo-escape",
                boardBackend: config.boardBackend,
                pieceBackend: config.pieceBackend,
                boardMS: nil,
                pieceMS: nil,
                totalMS: 12.345,
                detectionCount: nil,
                fenValid: nil,
                success: false,
                errorMessage: "piece_detection_failed: bad, \"quoted\"\nmessage"
            )
        )

        let contents = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("\"piece_detection_failed: bad, \"\"quoted\"\" message\""))
    }

    private func temporaryCSVURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("benchmark_runs.csv")
    }

    private func readCSVLines(at url: URL) throws -> [String] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return contents
            .split(whereSeparator: \.isNewline)
            .map(String.init)
    }
}
