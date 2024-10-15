//
//  ImageFormat.swift
//  Mindbox
//
//  Created by Дмитрий Ерофеев on 09.04.2024.
//

import Foundation
import ImageIO
import UIKit

enum ImageFormat: String {
    case png, jpg, gif

    init?(_ data: Data) {
        if let type = ImageFormat.get(from: data) {
            self = type
        } else {
            return nil
        }
    }
}

extension ImageFormat {

    private static func get(from data: Data?) -> ImageFormat? {
        
        guard let firstByte = data?.first else { return nil }
        
        switch firstByte {
        case 0x89:
            return .png
        case 0xFF:
            return .jpg
        case 0x47:
            return .gif
        default:
            return nil
        }
    }
    
    private static func animatedImage(withGIFData data: Data) -> UIImage? {
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        
        let frameCount = CGImageSourceGetCount(source)
        var frames: [UIImage] = []
        var gifDuration = 0.0
        
        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil),
               let gifInfo = (properties as NSDictionary)[kCGImagePropertyGIFDictionary as String] as? NSDictionary,
               let frameDuration = (gifInfo[kCGImagePropertyGIFDelayTime as String] as? NSNumber) {
                gifDuration += frameDuration.doubleValue
            }
            
            let frameImage = UIImage(cgImage: cgImage)
            frames.append(frameImage)
        }
        
        let animatedImage = UIImage.animatedImage(with: frames, duration: gifDuration)
        return animatedImage
    }
    
    static func getImage(imageData: Data?) -> UIImage? {
        
        guard let imageData else { return nil  }
        let imageFormat = ImageFormat.get(from: imageData)

        switch imageFormat {
        case .gif:
            return animatedImage(withGIFData: imageData)
        default:
            return UIImage(data: imageData)
        }
    }
}
