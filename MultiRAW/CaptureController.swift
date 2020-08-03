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

struct CaptureImage {
    let id: Int64
    let expected: Int
    var previewImage: UIImage?
    var images: [AVCapturePhoto]
}

extension AVCapturePhoto {
    var orientation: UIImage.Orientation? {
        let oint = metadata[kCGImagePropertyOrientation as String] as? Int
        if let raw = oint, let o = UIImage.Orientation(rawValue: raw) {
            return o
        } else {
            return nil
        }
    }
}

class CaptureController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {

    var running = false
    
    @Published var capturing = false
 
    @Published var captureSession = AVCaptureSession()
    
    @Published var recentCapture: CaptureImage?

    private let sessionQueue = DispatchQueue(label: "session queue")

    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
                                                                               mediaType: .video, position: .unspecified)

    // Properties must be read on session queue
    private var photoOutput: AVCapturePhotoOutput?
    private var photoSettings: AVCapturePhotoBracketSettings?
    private var currentCapture: CaptureImage?

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

        let settings = try makeBracketSettings(photoOutput: photoOutput, exposures: [-2, 0, 2])
        
        // Tell the photo output we want to
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

    private func makeBracketSettings(photoOutput: AVCapturePhotoOutput, exposures: [Float]) throws -> AVCapturePhotoBracketSettings {

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

//        if let previewFormat = settings.availablePreviewPhotoPixelFormatTypes.first {
//            settings.previewPhotoFormat = [String(kCVPixelBufferPixelFormatTypeKey): previewFormat]
//        }
        if let thumbnailFormat = settings.availableRawEmbeddedThumbnailPhotoCodecTypes.first {
            settings.rawEmbeddedThumbnailPhotoFormat = [AVVideoCodecKey: thumbnailFormat]
        }

        return settings
    }

    func start() {
        running = true

        sessionQueue.async {
            try? self.configureSession(session: self.captureSession)
            self.captureSession.startRunning()
        }
        
    }
    
    func capture() {
        sessionQueue.async {
            if let photoOutput = self.photoOutput {
                if let photoSettings = try? self.makeBracketSettings(photoOutput: photoOutput, exposures: [-2, 0, 2]) {
                    photoOutput.capturePhoto(with: photoSettings, delegate: self)
                    DispatchQueue.main.async {
                        self.capturing = true
                    }
                }
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        sessionQueue.async {
            let c = CaptureImage(id: resolvedSettings.uniqueID, expected: resolvedSettings.expectedPhotoCount, images: [])
            self.currentCapture = c
            DispatchQueue.main.async {
                self.recentCapture = c
            }
        }
    }
    
    func savePhoto(capture: CaptureImage) {
        let l = PHPhotoLibrary.shared()
        l.performChanges({
            
            #if false
            let expectedTypes: [PHAssetResourceType] = capture.images.enumerated().map{i, _  in
                i == 0 ? .photo : .alternatePhoto
            }
            guard PHAssetCreationRequest.supportsAssetResourceTypes(expectedTypes.map{$0.rawValue as NSNumber}) else {
                print("Can't save asset with this collection of types: \(expectedTypes)")
                return
            }
            #endif
            
            for (i, photo) in capture.images.enumerated() {
                if photo.isRawPhoto {
                    if let data = photo.fileDataRepresentation() {
                        let createAsset = PHAssetCreationRequest.forAsset()
                        let opt = PHAssetResourceCreationOptions()
                        opt.originalFilename = "photo-exp-\(i).dng"
                        opt.uniformTypeIdentifier = AVFileType.dng.rawValue
                        createAsset.addResource(with: .photo, data: data, options: opt)
                    }
                }
            }
            
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
        self.sessionQueue.async {
            // Update current capture with this photo
            guard var currentCapture = self.currentCapture else {
                fatalError("didFinishProcessingPhoto with no current capture")
            }

            var images = currentCapture.images
            images.append(photo)
            currentCapture.images = images
            if let preview = photo.previewCGImageRepresentation()?.takeUnretainedValue() {
                let orientation = photo.orientation
                currentCapture.previewImage = UIImage(cgImage: preview,
                                                      scale: 1.0,
                                                      orientation: orientation ?? .up)
            }
            self.currentCapture = currentCapture
            
            // Message main thread with out progress
            DispatchQueue.main.async {
                self.recentCapture = currentCapture
            }

        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        self.sessionQueue.async {
            DispatchQueue.main.async {
                self.capturing = false
            }
            if let currentCapture = self.currentCapture {
                DispatchQueue.global(qos: .default).async {
                    self.savePhoto(capture: currentCapture)
                }
            }
        }
    }

    func stop() {
        let session = self.captureSession
        sessionQueue.async {
            session.stopRunning()
        }
    }
    
}
