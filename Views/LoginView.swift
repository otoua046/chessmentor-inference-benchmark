import SwiftUI

struct LoginView: View {
    let inferenceFactory: InferenceFactory
    @Binding var selectedPipelineMode: PipelineMode
    let effectivePipelineMode: PipelineMode
    let launchOverridePipelineMode: PipelineMode?
    let showsBenchmarkControls: Bool

    // Define color constants for reusability
    let primaryColor = Color(red: 255/255, green: 200/255, blue: 124/255)
    let accentColor = Color(red: 193/255, green: 129/255, blue: 40/255)
    let backgroundColor = Color(red: 46/255, green: 33/255, blue: 27/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center, spacing: 60) {
                    VStack(spacing: 10) {
                        Image("knightIcon")

                        VStack(spacing: 20) {
                            welcomeText
                            descriptionText
                        }
                    }
                    NavigationLink {
                        LiveAnalysisView(inferenceFactory: inferenceFactory)
                    } label: {
                        Label("Live Analysis (No Photos)", systemImage: "camera.viewfinder")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    NavigationLink(destination: ScanningView(inferenceFactory: inferenceFactory)) {
                        actionButton
                    }
                    .accessibilityIdentifier("GetStartedLink")

                    if showsBenchmarkControls {
                        benchmarkControls
                    }

                    learnMoreText
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor)
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Subviews

    private var welcomeText: some View {
        VStack(spacing: 7) {
            Text("Welcome to")
                .font(Font.custom("SFProDisplay-Bold", size: 40))
                .fontWeight(.heavy)
                .foregroundStyle(.white)
            
            Text("Chess Mentor")
                .font(Font.custom("SFProDisplay-Bold", size: 40))
                .fontWeight(.heavy)
                .foregroundStyle(primaryColor)
        }
    }

    private var descriptionText: some View {
        Text("AI-powered insights to elevate your chess game.")
            .font(Font.custom("SFProDisplay-Regular", size: 16))
            .foregroundStyle(.white)
    }

    private var actionButton: some View {
        Text("Get Started")
        .frame(width: 150, height: 50)
        .background(LinearGradient(colors: [accentColor, primaryColor], startPoint: .leading, endPoint: .trailing))
        .cornerRadius(13)
        .foregroundColor(.white)
        .font(Font.custom("SFProDisplay-Regular", size: 24))
        .accessibilityIdentifier("GetStartedButton")
    }

    private var learnMoreText: some View {
        Text("Learn more...")
            .font(Font.custom("SFProDisplay-Regular", size: 17))
            .underline()
            .foregroundStyle(primaryColor)
    }

    private var benchmarkControls: some View {
        VStack(spacing: 10) {
            Text("Benchmark Pipeline")
                .font(.headline)
                .foregroundStyle(.white)

            Picker("Pipeline Mode", selection: $selectedPipelineMode) {
                ForEach(PipelineMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(launchOverridePipelineMode != nil)

            Text(statusText)
                .font(.footnote)
                .foregroundStyle(primaryColor)
                .multilineTextAlignment(.center)

            NavigationLink {
                PhotoBenchmarkView(inferenceFactory: inferenceFactory)
            } label: {
                Label("Run Photo Benchmark", systemImage: "chart.xyaxis.line")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var statusText: String {
        if let launchOverridePipelineMode {
            return "Launch override active: \(launchOverridePipelineMode.displayName). Picker applies after removing PIPELINE_MODE."
        }

        return "Active mode: \(effectivePipelineMode.displayName). Applies to the next analysis run."
    }
}

#Preview {
    LoginView(
        inferenceFactory: InferenceFactory(mode: .hosted, roboflowApiKey: "PREVIEW"),
        selectedPipelineMode: .constant(.hosted),
        effectivePipelineMode: .hosted,
        launchOverridePipelineMode: nil,
        showsBenchmarkControls: true
    )
}
