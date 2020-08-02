//
//  Capture.swift
//  MultiRAW
//
//  Created by Andrew Pouliot on 8/1/20.
//

import Foundation
import AVFoundation
import SwiftUI
import Photos

enum CaptureError: Error {
    case noDeviceFound
    case unableToObtainVideoInput
    case unableToAddInputs
    case rawUnsupported
}

extension FourCharCode {
    var debugDescription: String {
        let array = withUnsafeBytes(of: self.littleEndian, Array.init)
        let chars: [Character] = array.map{ Character(Unicode.Scalar($0)) }
        return String(chars)
    }

}

class Capture: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {

    var running = false
    
    @Published var capturing = false
 
    @Published var captureSession = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "session queue")

    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
                                                                               mediaType: .video, position: .unspecified)

    // Properties must be read on session queue
    private var photoOutput: AVCapturePhotoOutput?
    private var photoSettings: AVCapturePhotoBracketSettings?

    private func configureSession(session: AVCaptureSession) throws {
        // Get camera device.
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CaptureError.noDeviceFound
        }
        // Create a capture input.
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            throw CaptureError.unableToObtainVideoInput
        }

        let photoOutput = AVCapturePhotoOutput()
        photoOutput.isHighResolutionCaptureEnabled = true

        // Make sure inputs and output can be added to session.
        guard session.canAddInput(videoInput) else {
            throw CaptureError.unableToAddInputs
        }
        guard session.canAddOutput(photoOutput) else {
            throw CaptureError.unableToAddInputs
        }

        // Configure the session.
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.addInput(videoInput)
        session.addOutput(photoOutput)

        guard let rawPixelFormat = photoOutput.availableRawPhotoPixelFormatTypes.first else {
            throw CaptureError.rawUnsupported
        }
        guard let processedFormat = [.hevc, .jpeg].first(where: { photoOutput.availablePhotoCodecTypes.contains($0)}) else {
            throw CaptureError.unableToObtainVideoInput
        }
        
        let makeSettings = AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings
        let bracketedStillImageSettings = [-2, 0, 2].map { makeSettings(Float($0)) }
        
        let settings = AVCapturePhotoBracketSettings(rawPixelFormatType: rawPixelFormat,
                                                     processedFormat: [AVVideoCodecKey: processedFormat],
                                                     bracketedSettings: bracketedStillImageSettings)
        
        photoOutput.setPreparedPhotoSettingsArray([settings]) { (ok, err) in
            if let err = err {
                print("Was not able to prepare \(err)")
            } else {
                print("Was able to prepare")
            }
        }
        settings.isLensStabilizationEnabled = photoOutput.isLensStabilizationDuringBracketedCaptureSupported
        
        self.photoOutput = photoOutput
        self.photoSettings = settings

        session.commitConfiguration()
    }


    func start() {
        running = true

        sessionQueue.async {
            #if !targetEnvironment(simulator)
            try? self.configureSession(session: self.captureSession)
            self.captureSession.startRunning()
            #endif
            
        }
        
    }
    
    func capture() {
        sessionQueue.async {
            if let photoOutput = self.photoOutput, let photoSettings = self.photoSettings {
                photoOutput.capturePhoto(with: photoSettings, delegate: self)
                DispatchQueue.main.async {
                    self.capturing = true
                }
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        
    }
    
    func savePhoto(data: Data) {
        let l = PHPhotoLibrary.shared()
        l.performChanges({
            let createAsset = PHAssetCreationRequest.forAsset()
            let opt = PHAssetResourceCreationOptions()
            opt.originalFilename = "photo.dng"
            opt.uniformTypeIdentifier = AVFileType.dng.rawValue
            createAsset.addResource(with: PHAssetResourceType.photo, data: data, options: opt)
            
        }) { (ok, error) in
            DispatchQueue.main.async {
                // Report result
                if ok {
                    print("Saved photo")
                } else {
                    print("Report error! \(String(describing: error))")
                }
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        DispatchQueue.main.async {
            self.capturing = false
        }
        guard let data = photo.fileDataRepresentation() else {
            // Report error??
            print("Error getting photo data")
            return
        }

        savePhoto(data: data)
    }

    func stop() {
        let session = self.captureSession
        sessionQueue.async {
            session.stopRunning()
        }
    }
    
}
