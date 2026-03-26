import UIKit
import XCTest
@testable import chessMentor

private actor BenchmarkSequenceProbe {
    private var activeCalls = 0
    private var maxActiveCalls = 0
    private var detectCallCount = 0

    func beginCall() -> Int {
        activeCalls += 1
        maxActiveCalls = max(maxActiveCalls, activeCalls)
        detectCallCount += 1
        return detectCallCount
    }

    func endCall() {
        activeCalls -= 1
    }

    func snapshot() -> (maxActiveCalls: Int, detectCallCount: Int) {
        (maxActiveCalls, detectCallCount)
    }
}

private struct SequencedPieceDetector: PieceDetectionServing {
    let responses: [[Prediction]]
    let probe: BenchmarkSequenceProbe

    func detect(on image: UIImage) async throws -> [Prediction] {
        let callIndex = await probe.beginCall()
        try? await Task.sleep(nanoseconds: 20_000_000)
        let responseIndex = min(callIndex - 1, responses.count - 1)
        let response = responses[max(0, responseIndex)]
        await probe.endCall()
        return response
    }
}

private func benchmarkRunnerImage(_ size: CGSize = .init(width: 800, height: 800)) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
}

private func benchmarkRunnerCenter(_ file: Character, _ rank: Int) -> (CGFloat, CGFloat) {
    let square: CGFloat = 100
    let fileIndex = Int(file.asciiValue! - Character("a").asciiValue!)
    let rowTop = 8 - rank
    return ((CGFloat(fileIndex) + 0.5) * square, (CGFloat(rowTop) + 0.5) * square)
}

private func benchmarkRunnerPiece(
    _ file: Character,
    _ rank: Int,
    _ pieceClass: String,
    conf: CGFloat = 0.95
) -> Prediction {
    let (x, y) = benchmarkRunnerCenter(file, rank)
    return Prediction(x: x, y: y, width: 88, height: 88, class: pieceClass, confidence: conf)
}

private func benchmarkRunnerLogger(outputURL: URL, sessionID: String) -> BenchmarkLogger {
    let config = BenchmarkConfig(
        pipelineMode: .hosted,
        boardBackend: "hosted_roboflow_api",
        pieceBackend: "hosted_roboflow_api",
        enabledOverride: true,
        outputURL: outputURL,
        sessionID: sessionID
    )
    return BenchmarkLogger(config: config)
}

private func benchmarkRunnerCSVLines(at url: URL) throws -> [String] {
    let contents = try String(contentsOf: url, encoding: .utf8)
    return contents
        .split(whereSeparator: \.isNewline)
        .map(String.init)
}

private func benchmarkRunnerOutputURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent(PhotoBenchmarkConfiguration.outputFileName)
}

final class PhotoBenchmarkRunnerTests: XCTestCase {

    @MainActor
    func testRunnerExecutesSequentiallyLabelsRunsAndContinuesAfterFailure() async throws {
        let outputURL = benchmarkRunnerOutputURL()
        let board = benchmarkRunnerImage()
        let probe = BenchmarkSequenceProbe()
        let validPredictions: [Prediction] = [
            benchmarkRunnerPiece("e", 1, "w-king", conf: 0.40),
            benchmarkRunnerPiece("e", 8, "b-king", conf: 0.40),
            benchmarkRunnerPiece("e", 2, "w-pawn"),
            benchmarkRunnerPiece("d", 7, "b-pawn"),
        ]
        let invalidPredictions = [benchmarkRunnerPiece("e", 1, "w-king")]

        let runner = PhotoBenchmarkRunner(
            assetName: PhotoBenchmarkConfiguration.defaultAssetName,
            warmupRuns: 1,
            measuredRuns: 2,
            outputURL: outputURL,
            makeResultsViewModel: { configuration in
                ResultsViewModel(
                    cropper: MockCropper(image: board),
                    pieceDetector: SequencedPieceDetector(
                        responses: [
                            validPredictions,
                            invalidPredictions,
                            validPredictions,
                        ],
                        probe: probe
                    ),
                    engine: ThrowingEngine(error: TestFailure.message("engine should not run")),
                    drawer: ArrowDrawer(),
                    saveDebugImages: false,
                    benchmarkLogger: benchmarkRunnerLogger(
                        outputURL: configuration.outputURL,
                        sessionID: configuration.sessionID
                    )
                )
            },
            imageLoader: { assetName in
                XCTAssertEqual(assetName, PhotoBenchmarkConfiguration.defaultAssetName)
                return board
            },
            sessionIDProvider: { "photo-benchmark-session" }
        )

        await runner.run()

        XCTAssertFalse(runner.isRunning)
        XCTAssertEqual(runner.completedRuns, 3)
        XCTAssertEqual(runner.successfulRuns, 2)
        XCTAssertEqual(runner.failedRuns, 1)
        XCTAssertEqual(runner.lastSessionID, "photo-benchmark-session")
        XCTAssertEqual(
            runner.statusMessage,
            "Benchmark complete. Completed 3/3 runs. Success: 2. Failures: 1."
        )

        let snapshot = await probe.snapshot()
        XCTAssertEqual(snapshot.maxActiveCalls, 1)
        XCTAssertEqual(snapshot.detectCallCount, 3)

        let lines = try benchmarkRunnerCSVLines(at: outputURL)
        XCTAssertEqual(lines.count, 4)
        XCTAssertTrue(lines[1].contains(",photo-benchmark-session,"))
        XCTAssertTrue(lines[1].contains(",ui_test_board:warmup:001,"))
        XCTAssertTrue(lines[2].contains(",ui_test_board:measured:001,"))
        XCTAssertTrue(lines[2].contains(",1,false,false,invalid_fen:"))
        XCTAssertTrue(lines[3].contains(",ui_test_board:measured:002,"))
        XCTAssertTrue(lines[3].contains(",4,true,true,"))
    }
}
