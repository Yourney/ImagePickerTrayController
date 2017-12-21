//
//  CameraCell.swift
//  ImagePickerTrayController
//
//  Created by Laurin Brandner on 15.10.16.
//  Copyright © 2016 Laurin Brandner. All rights reserved.
//

import UIKit

class CameraCell: UICollectionViewCell {
    
    var cameraView: CameraView? {
        willSet {
            if let cv = self.cameraView {
                cv.stopCamera()
                cv.removeFromSuperview()
            }
        }
        didSet {
            if let cameraView = self.cameraView {
                self.contentView.addSubview(cameraView)
                cameraView.translatesAutoresizingMaskIntoConstraints = false
                
                cameraView.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
                cameraView.leftAnchor.constraint(equalTo: self.contentView.leftAnchor).isActive = true
                cameraView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor).isActive = true
                cameraView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
                cameraView.setupAVCapture()
                
                self.cameraView = cameraView
            }
        }
    }
    
    var cameraOverlayView: CameraOverlayView? {
        willSet {
            self.cameraOverlayView?.removeFromSuperview()
        }
        didSet {
            if let overlay = self.cameraOverlayView {
                overlay.translatesAutoresizingMaskIntoConstraints = false
                self.contentView.addSubview(overlay)
                
                overlay.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
                overlay.leftAnchor.constraint(equalTo: self.contentView.leftAnchor).isActive = true
                overlay.rightAnchor.constraint(equalTo: self.contentView.rightAnchor).isActive = true
                overlay.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
                
                overlay.flipCameraButton.addTarget(self, action: #selector(flipAction), for: .touchUpInside)
                overlay.addTarget(self, action: #selector(photoAction), for: .touchUpInside)
            }
        }
    }

    @objc func flipAction() {
        self.cameraView?.flipCamera()
    }
    
    @objc func photoAction() {
        self.cameraView?.takePhoto()
    }
}

