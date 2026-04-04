import Foundation
import UIKit
import OSLog
import Roboflow

private let onDeviceBoardRFLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "chessmentor",
    category: "RoboflowOnDeviceBoardCrop"
)

protocol BoardDetectionServing {
    func detect(on image: UIImage) async throws -> [Prediction]
}

final class RoboflowOnDeviceBoardCropInferenceService {

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
            confidence: Double = 0.25,
            overlap: Double = 0.20,
            maxObjects: Float = 4,
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
                return "Failed to load on-device Roboflow board crop model: \(message)"
            case .unsupportedModelType(let message):
                return "Unsupported Roboflow model type for board cropping: \(message)"
            case .inference(let message):
                return "On-device Roboflow board crop inference failed: \(message)"
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
        modelId: String,
        confidence: Double = 0.25,
        overlap: Double = 0.20,
        maxObjects: Float = 4,
        apiURL: String = "https://api.roboflow.com"
    ) {
        let model = Self.parseModelID(modelId)
        self.init(
            configuration: Configuration(
                apiKey: apiKey,
                modelName: model.name,
                modelVersion: model.version,
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
        onDeviceBoardRFLog.info("On-device board crop OK. predictions=\(mapped.count, privacy: .public)")
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
            threshold: configuration.confidence,
            overlap: configuration.overlap,
            maxObjects: configuration.maxObjects
        )

        loadedModel = model
        onDeviceBoardRFLog.info(
            "Loaded on-device board crop model \(self.configuration.modelName, privacy: .public)/\(self.configuration.modelVersion, privacy: .public)"
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

    private static func parseModelID(_ modelID: String) -> (name: String, version: Int) {
        let parts = modelID.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2, let version = Int(parts[1]) else {
            return (modelID, 1)
        }

        return (parts[0], version)
    }
}

extension RoboflowOnDeviceBoardCropInferenceService: BoardDetectionServing {}
