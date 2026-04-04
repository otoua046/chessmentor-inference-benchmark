import SwiftUI
import AVFoundation

/// SwiftUI wrapper for displaying a live video feed from an AVCaptureSession.
/// Uses UIKit's `AVCaptureVideoPreviewLayer` under the hood to render camera frames.
struct CameraPreviewView: UIViewRepresentable {

    /// The camera capture session whose video output will be displayed.
    let session: AVCaptureSession

    /// Creates the underlying UIKit view containing the video preview layer.
    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill // fill screen while preserving aspect ratio
        return v
    }

    /// Required by `UIViewRepresentable` but unused, as updates are handled by the session directly.
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    /// UIKit container view whose backing layer is an `AVCaptureVideoPreviewLayer`,
    /// allowing camera preview to be shown inside SwiftUI.
    final class PreviewUIView: UIView {

        /// Overrides the default view layer to use an AVCapture video layer instead of CALayer.
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        /// Helper to safely cast the view's backing layer.
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
