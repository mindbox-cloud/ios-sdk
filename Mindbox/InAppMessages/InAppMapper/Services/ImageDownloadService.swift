//
//  ImageDownloadService.swift
//  Mindbox
//
//  Created by vailence on 30.05.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

protocol ImageDownloadServiceProtocol {
    func downloadImage(withUrl url: String, completion: @escaping (Result<UIImage, Error>) -> Void)
}

class ImageDownloadService: ImageDownloadServiceProtocol {
    let imageDownloader: ImageDownloader

    init(imageDownloader: ImageDownloader) {
        self.imageDownloader = imageDownloader
    }

    func downloadImage(withUrl url: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.imageDownloader.downloadImage(withUrl: url) { localURL, response, error in
            if let error = error as? NSError {
                Logger.common(message: "Failed to download image for url: \(url). \nError: \(error.localizedDescription)", level: .debug, category: .inAppMessages)
                if error.code == NSURLErrorTimedOut {
                    completion(.failure(error))
                }
            } else if let response = response, response.statusCode != 200 {
                Logger.common(message: "Image download failed with status code \(response.statusCode). [URL]: \(url)", level: .debug, category: .inAppMessages)
                let error = NSError(domain: "", code: response.statusCode, userInfo: nil)
                completion(.failure(error))
            } else if let localURL = localURL {
                do {
                    let imageData = try Data(contentsOf: localURL)
                    guard let image = UIImage(data: imageData) else {
                        Logger.common(message: "Inapps image is incorrect. [URL]: \(localURL)", level: .debug, category: .inAppMessages)
                        let error = NSError(domain: "", code: NSURLErrorCannotDecodeContentData, userInfo: nil)
                        completion(.failure(error))
                        return
                    }
                    Logger.common(message: "Image is loaded successfully. [URL]: \(url)", level: .debug, category: .inAppMessages)
                    completion(.success(image))
                } catch {
                    Logger.common(message: "Failed to read image data. Error: \(error.localizedDescription)", level: .debug, category: .inAppMessages)
                    completion(.failure(error))
                }
            }
        }
    }
}
