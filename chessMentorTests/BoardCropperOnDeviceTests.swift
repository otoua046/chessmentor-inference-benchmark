import XCTest
import UIKit
@testable import chessMentor

final class BoardCropperOnDeviceTests: XCTestCase {

    private let apiKey = "SxJbV6TVzYIVMe0brpAk"

    private func loadStaticBoardImage() throws -> UIImage {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: "ui_test_board", withExtension: "jpg") else {
            XCTFail("Missing test resource: ui_test_board.jpg was not found in the chessMentorTests bundle.")
            throw NSError(
                domain: "BoardCropperOnDeviceTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing bundled resource ui_test_board.jpg."]
            )
        }

        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            XCTFail("Failed to decode bundled test image ui_test_board.jpg from \(url.path)")
            throw NSError(
                domain: "BoardCropperOnDeviceTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to decode bundled static board image."]
            )
        }
        return image
    }

    func testOnDeviceCropReturns800x800Image() throws {
        let image = try loadStaticBoardImage()
        let cropper = BoardCropper(
            apiKey: apiKey,
            boardModelId: hostedBoardCropperModelId,
            confidence: 0.25,
            overlap: 0.20,
            maxLongSide: 1280,
            padFrac: 0.03,
            enforceSquare: true,
            inferenceBackend: .onDevice
        )

        let cropped = try cropper.crop(image)

        XCTAssertEqual(Int(cropped.size.width), 800)
        XCTAssertEqual(Int(cropped.size.height), 800)
    }

    func testOnDeviceCropWithRectReturnsValidMappingMetadata() throws {
        let image = try loadStaticBoardImage()
        let cropper = BoardCropper(
            apiKey: apiKey,
            boardModelId: hostedBoardCropperModelId,
            confidence: 0.25,
            overlap: 0.20,
            maxLongSide: 1280,
            padFrac: 0.03,
            enforceSquare: true,
            inferenceBackend: .onDevice
        )

        let result = try cropper.cropWithRect(image)

        XCTAssertEqual(Int(result.cropped.size.width), 800)
        XCTAssertEqual(Int(result.cropped.size.height), 800)
        XCTAssertGreaterThan(result.rectInSource.width, 0)
        XCTAssertGreaterThan(result.rectInSource.height, 0)
        XCTAssertGreaterThan(result.sourceSize.width, 0)
        XCTAssertGreaterThan(result.sourceSize.height, 0)
        XCTAssertGreaterThanOrEqual(result.rectInSource.minX, 0)
        XCTAssertGreaterThanOrEqual(result.rectInSource.minY, 0)
        XCTAssertLessThanOrEqual(result.rectInSource.maxX, result.sourceSize.width)
        XCTAssertLessThanOrEqual(result.rectInSource.maxY, result.sourceSize.height)
    }
}
