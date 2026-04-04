import XCTest
@testable import chessMentor

final class InferenceFactoryTests: XCTestCase {

    @MainActor
    func testHostedFactoryBuildsHostedBackends() {
        let factory = InferenceFactory(mode: .hosted, roboflowApiKey: "test_key")

        XCTAssertTrue(factory.makePieceDetector() is RoboflowClient)
        XCTAssertTrue(factory.makeBoardDetector() is RoboflowClient)
        XCTAssertNotNil(factory.makeResultsViewModel())
        XCTAssertNotNil(factory.makeBoardDetectorAdapter())
    }

    @MainActor
    func testLocalFactoryBuildsLocalBackends() {
        let factory = InferenceFactory(mode: .local, roboflowApiKey: "test_key")

        XCTAssertTrue(factory.makePieceDetector() is RoboflowOnDevicePieceInferenceService)
        XCTAssertTrue(factory.makeBoardDetector() is RoboflowOnDeviceBoardCropInferenceService)
        XCTAssertNotNil(factory.makeResultsViewModel())
        XCTAssertNotNil(factory.makeBoardDetectorAdapter())
    }

    func testPipelineModeDefaultsToHostedForUnknownConfig() {
        XCTAssertEqual(PipelineMode(configurationValue: "unknown"), .hosted)
        XCTAssertEqual(PipelineMode(configurationValue: nil), .hosted)
        XCTAssertEqual(PipelineMode(configurationValue: "local"), .local)
    }

    func testPipelineModeOverrideOnlyAcceptsValidValues() {
        XCTAssertEqual(PipelineMode(overrideValue: "hosted"), .hosted)
        XCTAssertEqual(PipelineMode(overrideValue: " local "), .local)
        XCTAssertNil(PipelineMode(overrideValue: "unknown"))
        XCTAssertNil(PipelineMode(overrideValue: nil))
    }

    func testPipelineModeDisplayName() {
        XCTAssertEqual(PipelineMode.hosted.displayName, "Hosted")
        XCTAssertEqual(PipelineMode.local.displayName, "Local")
        XCTAssertEqual(PipelineMode.allCases.count, 2)
    }

    func testMakeBenchmarkLoggerReturnsNilWhenDisabled() {
        let factory = InferenceFactory(mode: .hosted, roboflowApiKey: "test_key")

        XCTAssertNil(factory.makeBenchmarkLogger(enabledOverride: false))
    }

    func testMakeBenchmarkLoggerReturnsLoggerWhenEnabled() {
        let factory = InferenceFactory(mode: .local, roboflowApiKey: "test_key")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("benchmark_runs.csv")

        let logger = factory.makeBenchmarkLogger(
            enabledOverride: true,
            outputURL: outputURL
        )

        XCTAssertNotNil(logger)
    }

    func testMakeBenchmarkLoggerUsesProvidedSessionID() throws {
        let factory = InferenceFactory(mode: .hosted, roboflowApiKey: "test_key")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("benchmark_runs.csv")

        let logger = try XCTUnwrap(
            factory.makeBenchmarkLogger(
                enabledOverride: true,
                outputURL: outputURL,
                sessionID: "session-override"
            )
        )

        logger.append(
            BenchmarkRecord(
                timestamp: Date(timeIntervalSince1970: 1),
                sessionID: "session-override",
                device: "test-device",
                pipelineMode: PipelineMode.hosted.rawValue,
                flowType: BenchmarkFlowType.photo.rawValue,
                inputID: "photo-1",
                boardBackend: "hosted_roboflow_api",
                pieceBackend: "hosted_roboflow_api",
                boardMS: 1,
                pieceMS: 2,
                totalMS: 3,
                detectionCount: 4,
                fenValid: true,
                success: true,
                errorMessage: nil
            )
        )

        let contents = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertTrue(contents.contains(",session-override,"))
    }
}
