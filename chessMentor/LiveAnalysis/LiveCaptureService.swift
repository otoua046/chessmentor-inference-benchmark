import AVFoundation
import CoreMedia

/// Handles camera capture setup and frame delivery using AVCaptureSession.
/// Produces BGRA pixel buffers via callback so analysis can run elsewhere.
final class LiveCaptureService: NSObject, ObservableObject {

    /// Shared capture session driving video input and output.
    let session = AVCaptureSession()

    /// Queue used for sample buffer processing to avoid blocking main UI thread.
    private let queue = DispatchQueue(label: "camera.frames.queue")

    /// Video data output responsible for delivering pixel buffers.
    private let videoOutput = AVCaptureVideoDataOutput()

    /// Callback invoked for each BGRA frame received from camera pipeline.
    var onFrame: ((CVPixelBuffer) -> Void)?

    /// Public entry point to start camera capture. Handles authorization logic.
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            // Ask the user for camera permission, then configure the session on approval.
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                guard ok else { return }
                self?.configureAndStart()
            }
        default:
            // No access: do nothing. Caller can show UI explaining permission issues.
            break
        }
    }

    /// Stops capture session if running. Safe to call regardless of state.
    func stop() {
        if session.isRunning { session.stopRunning() }
    }

    /// Configures capture inputs/outputs and starts session.
    /// Removes existing inputs, attaches back camera, sets output pixel format,
    /// and ensures portrait orientation for video stream.
    private func configureAndStart() {
        guard !session.isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        // Remove existing inputs and add the default back camera if possible.
        session.inputs.forEach { session.removeInput($0) }
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { session.commitConfiguration(); return }
        session.addInput(input)

        // Replace any previous output and attach the delegate used for frame delivery.
        if session.outputs.contains(videoOutput) { session.removeOutput(videoOutput) }
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(videoOutput) else { session.commitConfiguration(); return }
        session.addOutput(videoOutput)

        // Keep the live stream aligned with the portrait UI.
        if let c = videoOutput.connection(with: .video), c.isVideoOrientationSupported {
            c.videoOrientation = .portrait
        }

        session.commitConfiguration()
        session.startRunning()
    }
}

/// Receives video sample buffers and forwards their pixel buffers through `onFrame`.
extension LiveCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        /// Extract the pixel buffer from the sample buffer and deliver it if available.
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pb)
    }
}
