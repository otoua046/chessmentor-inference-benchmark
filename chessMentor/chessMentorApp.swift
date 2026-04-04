import SwiftUI

/// Entry point for the Chess Mentor SwiftUI application, responsible for initializing the UI
/// and choosing the correct root view depending on whether the app is running in normal mode
/// or driven by UI tests.
@main
struct ChessMentorApp: App {
    @AppStorage("benchmark.pipeline_mode")
    private var storedPipelineMode = PipelineMode.hosted.rawValue

    private let roboflowApiKey = "SxJbV6TVzYIVMe0brpAk"

    /// Determines whether the app is currently running under a UI test scenario.
    /// Uses command-line arguments and environment variables to detect UITEST_MODE.
    /// When enabled, the app will bypass authentication and jump directly to a deterministic UI state.
    private var isUITestMode: Bool {
        let p = ProcessInfo.processInfo
        return p.arguments.contains("UITEST_MODE") || p.environment["UITEST_MODE"] == "1"
    }

    private var showsBenchmarkControls: Bool {
        let p = ProcessInfo.processInfo
        // Keep benchmark-only UI out of the default app flow unless it is explicitly enabled.
        return p.arguments.contains("SHOW_BENCHMARK_CONTROLS")
            || p.environment["SHOW_BENCHMARK_CONTROLS"] == "1"
    }

    private var launchOverridePipelineMode: PipelineMode? {
        PipelineMode(overrideValue: ProcessInfo.processInfo.environment["PIPELINE_MODE"])
    }

    private var selectedPipelineMode: PipelineMode {
        launchOverridePipelineMode ?? PipelineMode(configurationValue: storedPipelineMode)
    }

    private var selectedPipelineModeBinding: Binding<PipelineMode> {
        Binding {
            PipelineMode(configurationValue: storedPipelineMode)
        } set: { newValue in
            storedPipelineMode = newValue.rawValue
        }
    }

    private var inferenceFactory: InferenceFactory {
        InferenceFactory(
            mode: selectedPipelineMode,
            roboflowApiKey: roboflowApiKey
        )
    }

    /// Defines the main scene of the app. Displays either:
    /// - `ResultsView` with a mocked camera model for UI testing
    /// - `LoginView` for normal runtime behavior
    /// Uses a `NavigationStack` to support navigation throughout the app.
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if isUITestMode {
                    // In UI testing, immediately show a results screen with a known image
                    // so automated tests can run deterministically without interacting
                    // with hardware camera access.
                    ResultsView(camera: makeUITestCamera(), inferenceFactory: inferenceFactory)
                        .accessibilityIdentifier("results_root")
                } else {
                    // Default runtime: start at the login screen.
                    LoginView(
                        inferenceFactory: inferenceFactory,
                        selectedPipelineMode: selectedPipelineModeBinding,
                        effectivePipelineMode: selectedPipelineMode,
                        launchOverridePipelineMode: launchOverridePipelineMode,
                        showsBenchmarkControls: showsBenchmarkControls
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    /// Creates a camera model suitable for UI tests.
    /// - Sets the camera state to "taken" so views that expect a captured image behave normally.
    /// - Attempts to load a known board test image if it exists in assets.
    /// - Falls back to generating a small gray image to prevent crashes during tests if the asset is missing.
    private func makeUITestCamera() -> CameraModel {
        let cam = CameraModel()
        cam.isTaken = true
        // Use the bundled UI test board if present; otherwise a tiny gray placeholder prevents crashes.
        if let img = UIImage(named: "ui_test_board") {
            cam.capturedPhoto = img
        } else {
            cam.capturedPhoto = UIImage.solidColor(.systemGray, size: CGSize(width: 4, height: 4))
        }
        return cam
    }
}

/// Helper for generating a solid-color UIImage programmatically.
/// Used primarily for UI testing fallback images where an actual asset might not exist.
private extension UIImage {
    /// Creates a plain colored rectangle image of a given size.
    /// This avoids crashes when a placeholder image is required during automated tests.
    static func solidColor(_ color: UIColor, size: CGSize) -> UIImage {
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
