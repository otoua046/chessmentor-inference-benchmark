import Foundation
import UIKit
import OSLog
import CoreGraphics
import Roboflow

private let onDeviceRFLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "chessmentor",
    category: "RoboflowOnDevice"
)

protocol PieceDetectionServing {
    func detect(on image: UIImage) async throws -> [Prediction]
}

final class RoboflowOnDevicePieceInferenceService {

    struct Configuration {
        let apiKey: String
        let modelName: String
        let modelVersion: Int
        let confidence: Double
        let overlap: Double
        let maxObjects: Float
        let apiURL: String

        init(
            apiKey: String,
            modelName: String,
            modelVersion: Int,
            confidence: Double = 0.30,
            overlap: Double = 0.50,
            maxObjects: Float = 64,
            apiURL: String = "https://api.roboflow.com"
        ) {
            self.apiKey = apiKey
            self.modelName = modelName
            self.modelVersion = modelVersion
            self.confidence = confidence
            self.overlap = overlap
            self.maxObjects = maxObjects
            self.apiURL = apiURL
        }
    }

    enum Err: LocalizedError {
        case modelLoad(String)
        case unsupportedModelType(String)
        case inference(String)

        var errorDescription: String? {
            switch self {
            case .modelLoad(let message):
                return "Failed to load on-device Roboflow model: \(message)"
            case .unsupportedModelType(let message):
                return "Unsupported Roboflow model type for piece detection: \(message)"
            case .inference(let message):
                return "On-device Roboflow inference failed: \(message)"
            }
        }
    }

    private let configuration: Configuration
    private let roboflow: RoboflowMobile
    private var loadedModel: RFModel?

    init(configuration: Configuration) {
        self.configuration = configuration
        self.roboflow = RoboflowMobile(
            apiKey: configuration.apiKey,
            apiURL: configuration.apiURL
        )
    }

    convenience init(
        apiKey: String,
        modelName: String,
        modelVersion: Int,
        confidence: Double = 0.30,
        overlap: Double = 0.50,
        maxObjects: Float = 64,
        apiURL: String = "https://api.roboflow.com"
    ) {
        self.init(
            configuration: Configuration(
                apiKey: apiKey,
                modelName: modelName,
                modelVersion: modelVersion,
                confidence: confidence,
                overlap: overlap,
                maxObjects: maxObjects,
                apiURL: apiURL
            )
        )
    }

    func detect(on image: UIImage) async throws -> [Prediction] {
        let model = try await loadModelIfNeeded()
        let (predictions, error) = await model.detect(image: image)

        if let error {
            throw Err.inference(error.localizedDescription)
        }

        let mapped = (predictions ?? []).compactMap(mapPrediction(_:))
        onDeviceRFLog.info("On-device Roboflow OK. predictions=\(mapped.count, privacy: .public)")
        return mapped
    }

    private func loadModelIfNeeded() async throws -> RFModel {
        if let loadedModel {
            return loadedModel
        }

        let (model, error, modelName, modelType) = await roboflow.load(
            model: configuration.modelName,
            modelVersion: configuration.modelVersion
        )

        if let error {
            throw Err.modelLoad(error.localizedDescription)
        }

        guard let model else {
            throw Err.modelLoad("Roboflow returned no model instance.")
        }

        guard model is RFObjectDetectionModel else {
            throw Err.unsupportedModelType(
                modelType.isEmpty ? "Unknown type for \(modelName)" : "\(modelType) for \(modelName)"
            )
        }

        model.configure(
            threshold: self.configuration.confidence,
            overlap: self.configuration.overlap,
            maxObjects: self.configuration.maxObjects
        )

        loadedModel = model
        onDeviceRFLog.info(
            "Loaded on-device Roboflow model \(self.configuration.modelName, privacy: .public)/\(self.configuration.modelVersion, privacy: .public)"
        )
        return model
    }

    private func mapPrediction(_ prediction: RFPrediction) -> Prediction? {
        guard let detection = prediction as? RFObjectDetectionPrediction else {
            return nil
        }

        return Prediction(
            x: CGFloat(detection.x),
            y: CGFloat(detection.y),
            width: CGFloat(detection.width),
            height: CGFloat(detection.height),
            class: detection.className,
            confidence: CGFloat(detection.confidence)
        )
    }
}

extension RoboflowOnDevicePieceInferenceService: PieceDetectionServing {}
