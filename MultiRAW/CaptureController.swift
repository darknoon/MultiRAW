import Foundation
import AVFoundation
import Photos
import Combine
import UIKit

enum CaptureError: Error {
    case noDeviceFound
    case unableToObtainVideoInput
    case unableToPrepareRawCaptureSettings(Error)
    case unableToAddInputs
    case rawUnsupported
    case processedPhotoWithNoCapture
}

extension CaptureError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noDeviceFound:
            return NSLocalizedString("No device found", comment: "Error string")
        case .unableToAddInputs:
            return NSLocalizedString("Unable to add inputs", comment: "Error string")
        case .rawUnsupported:
            return NSLocalizedString("RAW is not supported on this device", comment: "Error string")
        case .unableToObtainVideoInput:
            return NSLocalizedString("Unable to obtain video input", comment: "Error string")

        case .unableToPrepareRawCaptureSettings(_):
            return NSLocalizedString("Unable to prepare RAW capture settings. Capture may work regardless.", comment: "Error string")

        case .processedPhotoWithNoCapture:
            return NSLocalizedString("An internal error has occurred.", comment: "Error string")

        }
    }
}

struct CaptureImageEntry: Identifiable {
    let id: Int64
    var raw: AVCapturePhoto? = nil
    var processed: AVCapturePhoto? = nil
}

struct CaptureImage {
    let id: Int64
    let expected: Int
    var previewImage: UIImage?
    // Length will always be expected
    var images: [CaptureImageEntry]
    
    init(id: Int64, expected: Int, images: [CaptureImageEntry]? = nil, previewImage: UIImage? = nil) {
        self.id = id
        self.expected = expected
        if let images = images, images.count == expected {
            self.images = images
        } else {
            self.images = (0..<expected).map{
                CaptureImageEntry(id: id << 2 + Int64($0))
            }
        }
        self.previewImage = previewImage
    }
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
    
    // Subscribe to this for errors
    let errorStream = PassthroughSubject<Error, Never>()

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
                self.errorStream.send(CaptureError.unableToPrepareRawCaptureSettings(err))
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

        if let previewFormat = settings.availablePreviewPhotoPixelFormatTypes.first {
            settings.previewPhotoFormat = [String(kCVPixelBufferPixelFormatTypeKey): previewFormat]
        }
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
            let c = CaptureImage(id: resolvedSettings.uniqueID, expected: resolvedSettings.expectedPhotoCount / 2)
            self.currentCapture = c
            DispatchQueue.main.async {
                self.recentCapture = c
            }
        }
    }
    
    func savePhoto(capture: CaptureImage) {
        let l = PHPhotoLibrary.shared()
        l.performChanges({
            for (i, entry) in capture.images.enumerated() {
                if let raw = entry.raw {
                    if let data = raw.fileDataRepresentation() {
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
                self.errorStream.send(CaptureError.processedPhotoWithNoCapture)
                return
            }

            var images = currentCapture.images
            let i = photo.sequenceCount - 1
            var entry = images[i]
            if photo.isRawPhoto {
                entry.raw = photo
            } else {
                entry.processed = photo
            }
            images[i] = entry
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
