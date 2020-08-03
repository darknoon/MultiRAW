import Foundation
import UIKit
import AVFoundation
import SwiftUI

/**
 This just makes it easier to add an AVCaptureVideoPreviewLayer into SwiftUI since there is no CALayerRepresentable protocol
 */
class _AVLayerView: UIView {
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        return layer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
}

struct PreviewView: UIViewRepresentable {
    
    @Binding var captureSession: AVCaptureSession

    func makeUIView(context: Context) -> _AVLayerView {
        let pv = _AVLayerView()
        pv.session = captureSession
        return pv
    }

    func updateUIView(_ view: _AVLayerView, context: Context) {
        view.session = captureSession
    }
}
