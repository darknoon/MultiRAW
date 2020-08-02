//
//  Preview.swift
//  MultiRAW
//
//  Created by Andrew Pouliot on 8/1/20.
//

import Foundation
import UIKit
import AVFoundation
import SwiftUI

class PreviewUIView: UIView {
    
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

    func makeUIView(context: Context) -> PreviewUIView {
        let pv = PreviewUIView()
        pv.session = captureSession
        return pv
    }

    func updateUIView(_ view: PreviewUIView, context: Context) {
        view.session = captureSession
    }
}
