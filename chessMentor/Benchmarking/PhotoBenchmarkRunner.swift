import Foundation
import SwiftUI
import UIKit

struct PhotoBenchmarkConfiguration {
    static let defaultAssetName = "ui_test_board"
    static let defaultWarmupRuns = 10
    static let defaultMeasuredRuns = 150
    static let outputFileName = "photo_benchmark_runs.csv"

    let assetName: String
    let warmupRuns: Int
    let measuredRuns: Int
    let outputURL: URL
    let sessionID: String

    var totalRuns: Int {
        warmupRuns + measuredRuns
    }

    init(
        assetName: String = Self.defaultAssetName,
        warmupRuns: Int = Self.defaultWarmupRuns,
        measuredRuns: Int = Self.defaultMeasuredRuns,
        outputURL: URL = BenchmarkConfig.defaultOutputURL(fileName: Self.outputFileName),
        sessionID: String = UUID().uuidString
    ) {
        self.assetName = assetName
        self.warmupRuns = max(0, warmupRuns)
        self.measuredRuns = max(0, measuredRuns)
        self.outputURL = outputURL
        self.sessionID = sessionID
    }
}

@MainActor
final class PhotoBenchmarkRunner: ObservableObject {
    @Published var assetName: String
    @Published var warmupRuns: Int
    @Published var measuredRuns: Int

    @Published private(set) var isRunning = false
    @Published private(set) var completedRuns = 0
    @Published private(set) var totalRuns = 0
    @Published private(set) var successfulRuns = 0
    @Published private(set) var failedRuns = 0
    @Published private(set) var currentRunLabel: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var lastSessionID: String?

    let outputURL: URL

    private let makeResultsViewModel: (PhotoBenchmarkConfiguration) -> ResultsViewModel
    private let imageLoader: (String) -> UIImage?
    private let sessionIDProvider: () -> String

    convenience init(
        inferenceFactory: InferenceFactory,
        assetName: String = PhotoBenchmarkConfiguration.defaultAssetName,
        warmupRuns: Int = PhotoBenchmarkConfiguration.defaultWarmupRuns,
        measuredRuns: Int = PhotoBenchmarkConfiguration.defaultMeasuredRuns,
        outputURL: URL = BenchmarkConfig.defaultOutputURL(
            fileName: PhotoBenchmarkConfiguration.outputFileName
        ),
        imageLoader: @escaping (String) -> UIImage? = { UIImage(named: $0) },
        sessionIDProvider: @escaping () -> String = { UUID().uuidString }
    ) {
        self.init(
            assetName: assetName,
            warmupRuns: warmupRuns,
            measuredRuns: measuredRuns,
            outputURL: outputURL,
            makeResultsViewModel: { configuration in
                inferenceFactory.makeBenchmarkResultsViewModel(
                    outputURL: configuration.outputURL,
                    sessionID: configuration.sessionID
                )
            },
            imageLoader: imageLoader,
            sessionIDProvider: sessionIDProvider
        )
    }

    init(
        assetName: String = PhotoBenchmarkConfiguration.defaultAssetName,
        warmupRuns: Int = PhotoBenchmarkConfiguration.defaultWarmupRuns,
        measuredRuns: Int = PhotoBenchmarkConfiguration.defaultMeasuredRuns,
        outputURL: URL = BenchmarkConfig.defaultOutputURL(
            fileName: PhotoBenchmarkConfiguration.outputFileName
        ),
        makeResultsViewModel: @escaping (PhotoBenchmarkConfiguration) -> ResultsViewModel,
        imageLoader: @escaping (String) -> UIImage? = { UIImage(named: $0) },
        sessionIDProvider: @escaping () -> String = { UUID().uuidString }
    ) {
        self.assetName = assetName
        self.warmupRuns = warmupRuns
        self.measuredRuns = measuredRuns
        self.outputURL = outputURL
        self.makeResultsViewModel = makeResultsViewModel
        self.imageLoader = imageLoader
        self.sessionIDProvider = sessionIDProvider
    }

    var totalConfiguredRuns: Int {
        max(0, warmupRuns) + max(0, measuredRuns)
    }

    var progressFraction: Double {
        guard totalRuns > 0 else { return 0 }
        return Double(completedRuns) / Double(totalRuns)
    }

    var summaryText: String {
        "Completed \(completedRuns)/\(totalRuns) runs. Success: \(successfulRuns). Failures: \(failedRuns)."
    }

    func start() {
        guard !isRunning else { return }
        Task { @MainActor in
            await run()
        }
    }

    func run() async {
        guard !isRunning else { return }

        let configuration = PhotoBenchmarkConfiguration(
            assetName: assetName,
            warmupRuns: warmupRuns,
            measuredRuns: measuredRuns,
            outputURL: outputURL,
            sessionID: sessionIDProvider()
        )

        totalRuns = configuration.totalRuns
        completedRuns = 0
        successfulRuns = 0
        failedRuns = 0
        currentRunLabel = nil
        lastSessionID = configuration.sessionID

        guard totalRuns > 0 else {
            statusMessage = "Configure at least one warm-up or measured run."
            return
        }

        guard let image = imageLoader(configuration.assetName) else {
            statusMessage = "Failed to load bundled image \(configuration.assetName)."
            return
        }

        isRunning = true
        statusMessage = "Loaded \(configuration.assetName). Starting benchmark batch."

        let resultsViewModel = makeResultsViewModel(configuration)

        if configuration.warmupRuns > 0 {
            for index in 1...configuration.warmupRuns {
                await executeRun(
                    kind: .warmup,
                    index: index,
                    totalStageRuns: configuration.warmupRuns,
                    configuration: configuration,
                    image: image,
                    resultsViewModel: resultsViewModel
                )
            }
        }

        if configuration.measuredRuns > 0 {
            for index in 1...configuration.measuredRuns {
                await executeRun(
                    kind: .measured,
                    index: index,
                    totalStageRuns: configuration.measuredRuns,
                    configuration: configuration,
                    image: image,
                    resultsViewModel: resultsViewModel
                )
            }
        }

        currentRunLabel = nil
        statusMessage = "Benchmark complete. \(summaryText)"
        isRunning = false
    }

    private func executeRun(
        kind: RunKind,
        index: Int,
        totalStageRuns: Int,
        configuration: PhotoBenchmarkConfiguration,
        image: UIImage,
        resultsViewModel: ResultsViewModel
    ) async {
        currentRunLabel = "\(kind.displayName) \(index) of \(totalStageRuns)"
        statusMessage = "Running \(completedRuns + 1) of \(totalRuns)..."

        let inputID = Self.makeInputID(
            assetName: configuration.assetName,
            kind: kind,
            index: index
        )
        let result = await resultsViewModel.runBenchmark(with: image, inputID: inputID)

        completedRuns += 1
        if result.success {
            successfulRuns += 1
            statusMessage = "Completed \(currentRunLabel ?? inputID)."
        } else {
            failedRuns += 1
            let errorMessage = result.errorMessage ?? "Unknown error"
            statusMessage = "Failed \(currentRunLabel ?? inputID): \(errorMessage)"
        }
    }

    private static func makeInputID(
        assetName: String,
        kind: RunKind,
        index: Int
    ) -> String {
        "\(assetName):\(kind.idComponent):\(String(format: "%03d", index))"
    }

    private enum RunKind {
        case warmup
        case measured

        var displayName: String {
            switch self {
            case .warmup:
                return "Warm-up"
            case .measured:
                return "Measured"
            }
        }

        var idComponent: String {
            switch self {
            case .warmup:
                return "warmup"
            case .measured:
                return "measured"
            }
        }
    }
}
