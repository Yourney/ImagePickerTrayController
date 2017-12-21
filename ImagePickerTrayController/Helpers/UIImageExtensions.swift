//
//  UIImageExtensions.swift
//  ImagePickerTrayController
//
//  Created by Laurin Brandner on 24.11.16.
//  Copyright © 2016 Laurin Brandner. All rights reserved.
//

import UIKit

extension UIImage {
    
    convenience init?(bundledName name: String) {
        let bundle = Bundle(for: ImagePickerTrayController.self)
        self.init(named: name, in: bundle, compatibleWith:nil)
    }
    
    /// Correct the imageOrientation (when image came from camera)
    // http://stackoverflow.com/questions/5427656/ios-uiimagepickercontroller-result-image-orientation-after-upload
    public func normalizedImage() -> UIImage {
        
        if (self.imageOrientation == UIImageOrientation.up) {
            return self;
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale);
        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        self.draw(in: rect)
        
        let normalizedImage : UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext();
        return normalizedImage;
    }

}
