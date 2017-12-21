//
//  CameraView.swift
//  ImagePickerTrayController
//
//  Created by Wouter Wessels on 18/12/2017.
//  Copyright © 2017 Wouter Wessels. All rights reserved.
//

import UIKit
import AVFoundation

protocol CameraViewDelegate {
    func cameraView(cameraView: CameraView, didTake image: UIImage)
}

public final class CameraView : UIView, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    
    var delegate: CameraViewDelegate?
    
    let session = AVCaptureSession()
    var captureDevice : AVCaptureDevice!
    var previewLayer:AVCaptureVideoPreviewLayer!
    var cameraPosition: AVCaptureDevice.Position = .back
    
    var videoDataOutputQueue: DispatchQueue!

    var videoDataOutput = AVCaptureVideoDataOutput()
    var capturePhotoOutput = AVCapturePhotoOutput()
    
    // MARK: - Lifecycle
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        self.previewLayer.frame = self.bounds.smallestCenteredSquare
    }

    /// flip the camera to 'the other orientation': front -> back and vice versa
    internal func flipCamera() {
        self.session.beginConfiguration()
        if let currentInput = self.session.inputs.first as? AVCaptureDeviceInput {
            self.session.removeInput(currentInput)
            
            if let newCameraDevice = currentInput.device.position == .back ? getCamera(with: .front) : getCamera(with: .back),
                let newVideoInput = try? AVCaptureDeviceInput(device: newCameraDevice) {
                self.session.addInput(newVideoInput)
            }
        }

        self.session.commitConfiguration()
    }
    
    /// Setup and Start the camera session
    public func setupAVCapture() {
        session.sessionPreset = AVCaptureSession.Preset.vga640x480
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: self.cameraPosition) else {
            return
        }
        self.captureDevice = device
        configureSession()
        session.commitConfiguration()
        session.startRunning()
    }
    
    /// clean up AVCapture
    public func stopCamera() {
        session.stopRunning()
    }
    
    public func takePhoto() {
        let settings = AVCapturePhotoSettings()
        
        let videoOrientation: AVCaptureVideoOrientation
        let orientation = UIApplication.shared.statusBarOrientation
        switch orientation {
        case .unknown, .portrait:
                videoOrientation = .portrait
            case .portraitUpsideDown:
                videoOrientation = .portraitUpsideDown
            case .landscapeLeft:
                videoOrientation = .landscapeLeft
            case .landscapeRight:
            videoOrientation = .landscapeRight
        }
        
        if let photoOutputConnection = self.capturePhotoOutput.connection(with: AVMediaType.video) {
            photoOutputConnection.videoOrientation = videoOrientation
        }
        
        capturePhotoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    // iOS 11 (and newer)
    @available(iOS 11.0, *)
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print(error)
        }
        
        if let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data) {
            let normalizedImage = image.normalizedImage()
            self.delegate?.cameraView(cameraView: self, didTake: normalizedImage)
        }
    }
    
    // iOS 10 (and older)
    public func photoOutput(_ output: AVCapturePhotoOutput,
                            didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
                            previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                            resolvedSettings: AVCaptureResolvedPhotoSettings,
                            bracketSettings: AVCaptureBracketedStillImageSettings?,
                            error: Error?) {
        if let error = error {
            print(error)
        }
        
        if  let sampleBuffer = photoSampleBuffer,
            let previewBuffer = previewPhotoSampleBuffer,
            let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer:  sampleBuffer, previewPhotoSampleBuffer: previewBuffer),
            let image = UIImage(data: dataImage) {
            
            let normalizedImage = image.normalizedImage()
            self.delegate?.cameraView(cameraView: self, didTake: normalizedImage)
        }
    }
    
    private func getCamera(with position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position)
        return deviceSession.devices.first
    }

    private func configureSession() {
        var deviceInput:AVCaptureDeviceInput?
        do {
            deviceInput = try AVCaptureDeviceInput(device: captureDevice)
        } catch {
            print("error: \(String(describing: error.localizedDescription))");
        }
        
        if let deviceInput = deviceInput, self.session.canAddInput(deviceInput) {
            self.session.addInput(deviceInput)
        }
        
        self.videoDataOutput.alwaysDiscardsLateVideoFrames=true
        self.videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
        self.videoDataOutput.setSampleBufferDelegate(self, queue:self.videoDataOutputQueue)
        if self.session.canAddOutput(self.videoDataOutput){
            self.session.addOutput(self.videoDataOutput)
        }
        self.videoDataOutput.connection(with: AVMediaType.video)?.isEnabled = true
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.previewLayer.videoGravity = .resizeAspect	// fill whole frame with the preview layer
        
        // We make the previewLayer square, so that when rotated to landcape or portrait, it is easier to center it.
        // However, when in Landscape, the previewLayer will be larger than 'self.layer'.
        // Therefore we must set masksToBounds = false.
        self.layer.masksToBounds = false
        self.previewLayer.frame = self.layer.bounds.smallestCenteredSquare
        self.layer.addSublayer(self.previewLayer)
        
        // configure taking photos
        self.capturePhotoOutput.isHighResolutionCaptureEnabled = true
        self.capturePhotoOutput.isLivePhotoCaptureEnabled = self.capturePhotoOutput.isLivePhotoCaptureSupported

        guard self.session.canAddOutput(capturePhotoOutput) else {
            return
        }

        self.session.sessionPreset = AVCaptureSession.Preset.photo
        self.session.addOutput(capturePhotoOutput)
    }
    
}

private extension CGRect {
    var smallestCenteredSquare : CGRect {
        let maxSize = max(self.size.width, self.size.height)
        
        let x = (self.width - maxSize) / 2
        let y = (self.height - maxSize) / 2
        
        return CGRect(x: x, y: y, width: maxSize, height: maxSize)
    }
}
