import XCTest
import UIKit
@testable import chessMentor

final class RoboflowOnDevicePieceInferenceTests: XCTestCase {

    private func loadStaticBoardImage() throws -> UIImage {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: "ui_test_board", withExtension: "jpg") else {
            XCTFail("Missing bundled test resource: ui_test_board.jpg in chessMentorTests bundle.")
            throw NSError(
                domain: "RoboflowOnDevicePieceInferenceTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing bundled test resource: ui_test_board.jpg."]
            )
        }

        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            XCTFail("Failed to decode bundled test image at \(url.path)")
            throw NSError(
                domain: "RoboflowOnDevicePieceInferenceTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to decode bundled test image."]
            )
        }
        return image
    }

    func testDetectOnStaticBoardImageReturnsPredictions() async throws {
        let image = try loadStaticBoardImage()
        let service = RoboflowOnDevicePieceInferenceService(
            configuration: .init(
                apiKey: "SxJbV6TVzYIVMe0brpAk",
                modelName: "chessbot-v2",
                modelVersion: 1,
                confidence: 0.30,
                overlap: 0.50
            )
        )

        let predictions = try await service.detect(on: image)

        XCTAssertFalse(predictions.isEmpty, "Expected at least one on-device piece detection.")

        for prediction in predictions {
            XCTAssertFalse(prediction.class.isEmpty, "Prediction class should not be empty.")
            XCTAssertGreaterThanOrEqual(prediction.x, 0, "Prediction x should be non-negative.")
            XCTAssertGreaterThanOrEqual(prediction.y, 0, "Prediction y should be non-negative.")
            XCTAssertGreaterThanOrEqual(prediction.width, 0, "Prediction width should be non-negative.")
            XCTAssertGreaterThanOrEqual(prediction.height, 0, "Prediction height should be non-negative.")

            if let confidence = prediction.confidence {
                XCTAssertGreaterThanOrEqual(confidence, 0, "Prediction confidence should be non-negative.")
                XCTAssertLessThanOrEqual(confidence, 1, "Prediction confidence should be <= 1.")
            }
        }
    }
}
