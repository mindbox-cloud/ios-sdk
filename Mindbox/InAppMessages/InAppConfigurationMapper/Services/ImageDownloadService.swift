//
//  ImageDownloadService.swift
//  Mindbox
//
//  Created by vailence on 13.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

protocol ImageDownloadServiceProtocol {
    func downloadImage(withUrl url: String, completion: @escaping (Result<UIImage, MindboxError>) -> Void)
}

class ImageDownloadService: ImageDownloadServiceProtocol {
    let imageDownloader: ImageDownloader

    init(imageDownloader: ImageDownloader) {
        self.imageDownloader = imageDownloader
    }

    func downloadImage(withUrl url: String, completion: @escaping (Result<UIImage, MindboxError>) -> Void) {
        self.imageDownloader.downloadImage(withUrl: url) { localURL, response, error in
            if let error = error as? NSError {
                Logger.common(message: "Failed to download image. [URL]: \(url). \nError: \(error.localizedDescription)", level: .debug, category: .inAppMessages)
                completion(.failure(.unknown(error)))
            } else if let response = response, response.statusCode != 200 {
                Logger.common(message: "Image download failed with status code \(response.statusCode). [URL]: \(url)", level: .debug, category: .inAppMessages)
                let protocolError = ProtocolError(
                    status: (500..<600).contains(response.statusCode) ? .internalServerError : .protocolError,
                    errorMessage: "Image download failed with status code \(response.statusCode)",
                    httpStatusCode: response.statusCode
                )
                if (500..<600).contains(response.statusCode) {
                    completion(.failure(.serverError(protocolError)))
                } else {
                    completion(.failure(.protocolError(protocolError)))
                }
            } else if let localURL = localURL {
                do {
                    let imageData = try Data(contentsOf: localURL)
                    guard let image = ImageFormat.getImage(imageData: imageData) else {
                        Logger.common(message: "Inapps image is incorrect. [URL]: \(localURL)", level: .debug, category: .inAppMessages)
                        let error = NSError(domain: "", code: NSURLErrorCannotDecodeContentData, userInfo: nil)
                        completion(.failure(.unknown(error)))
                        return
                    }
                    Logger.common(message: "Image is loaded successfully. [URL]: \(url)", level: .debug, category: .inAppMessages)
                    completion(.success(image))
                } catch {
                    Logger.common(message: "Failed to read image data. Error: \(error.localizedDescription)", level: .debug, category: .inAppMessages)
                    completion(.failure(.unknown(error)))
                }
            } else {
                completion(.failure(.invalidResponse(response)))
            }
        }
    }
}
