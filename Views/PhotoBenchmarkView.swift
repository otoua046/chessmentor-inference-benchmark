import SwiftUI

struct PhotoBenchmarkView: View {
    @StateObject private var runner: PhotoBenchmarkRunner

    @MainActor
    init(inferenceFactory: InferenceFactory) {
        _runner = StateObject(
            wrappedValue: PhotoBenchmarkRunner(inferenceFactory: inferenceFactory)
        )
    }

    var body: some View {
        Form {
            Section("Configuration") {
                LabeledContent("Image", value: runner.assetName)

                Stepper(
                    "Warm-up runs: \(runner.warmupRuns)",
                    value: $runner.warmupRuns,
                    in: 0...1000
                )
                .disabled(runner.isRunning)

                Stepper(
                    "Measured runs: \(runner.measuredRuns)",
                    value: $runner.measuredRuns,
                    in: 0...2000
                )
                .disabled(runner.isRunning)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Output")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(runner.outputURL.path)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }

            Section("Run") {
                Button(runner.isRunning ? "Running..." : "Start Benchmark") {
                    runner.start()
                }
                .disabled(runner.isRunning || runner.totalConfiguredRuns == 0)

                if runner.totalRuns > 0 {
                    ProgressView(value: runner.progressFraction)
                    Text(runner.summaryText)
                        .font(.footnote)
                }

                if let currentRunLabel = runner.currentRunLabel {
                    Text(currentRunLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let statusMessage = runner.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                }

                if let sessionID = runner.lastSessionID {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Session ID")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(sessionID)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("Photo Benchmark")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PhotoBenchmarkView(
            inferenceFactory: InferenceFactory(mode: .hosted, roboflowApiKey: "PREVIEW")
        )
    }
}
