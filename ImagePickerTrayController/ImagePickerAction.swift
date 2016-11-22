//
//  ImagePickerAction.swift
//  ImagePickerTrayController
//
//  Created by Laurin Brandner on 22.11.16.
//  Copyright © 2016 Laurin Brandner. All rights reserved.
//

import Foundation

public struct ImagePickerAction {
    
    public typealias Callback = (ImagePickerAction) -> ()
    
    public var title: String
    public var image: UIImage
    public var callback: Callback
    
    public static func cameraAction(with callback: @escaping Callback) -> ImagePickerAction {
        let bundle = Bundle(for: ImagePickerTrayController.self)
        let image = UIImage(named: "ImagePickerAction-Camera", in: bundle, compatibleWith: nil)!
        
        return ImagePickerAction(title: NSLocalizedString("Camera", comment: "Image Picker Camera Action"), image: image, callback: callback)
    }
    
    public static func libraryAction(with callback: @escaping Callback) -> ImagePickerAction {
        let bundle = Bundle(for: ImagePickerTrayController.self)
        let image = UIImage(named: "ImagePickerAction-Library", in: bundle, compatibleWith: nil)!
        
        return ImagePickerAction(title: NSLocalizedString("Photo Library", comment: "Image Picker Photo Library Action"), image: image, callback: callback)
    }
    
    func call() {
        callback(self)
    }
    
}
