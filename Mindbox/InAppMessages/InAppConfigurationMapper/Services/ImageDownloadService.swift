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
            self.handleDownloadResult(
                sourceUrl: url,
                localURL: localURL,
                response: response,
                error: error,
                completion: completion
            )
        }
    }
}

private extension ImageDownloadService {
    func handleDownloadResult(
        sourceUrl: String,
        localURL: URL?,
        response: HTTPURLResponse?,
        error: Error?,
        completion: @escaping (Result<UIImage, MindboxError>) -> Void
    ) {
        if let nsError = error as? NSError {
            Logger.common(message: "Failed to download image. [URL]: \(sourceUrl). \nError: \(nsError.localizedDescription)", level: .debug, category: .inAppMessages)
            if nsError.isNetworkOrTimeoutError {
                completion(.failure(.connectionError))
            } else {
                completion(.failure(.unknown(nsError)))
            }
            return
        }

        if let response = response, response.statusCode != 200 {
            Logger.common(message: "Image download failed with status code \(response.statusCode). [URL]: \(sourceUrl)", level: .debug, category: .inAppMessages)
            completion(.failure(makeResponseError(for: response.statusCode)))
            return
        }

        if let localURL = localURL {
            completion(readImageFromDisk(localURL: localURL, sourceUrl: sourceUrl))
            return
        }

        completion(.failure(.invalidResponse(response)))
    }

    func makeResponseError(for statusCode: Int) -> MindboxError {
        let protocolError = ProtocolError(
            status: (500..<600).contains(statusCode) ? .internalServerError : .protocolError,
            errorMessage: "Image download failed with status code \(statusCode)",
            httpStatusCode: statusCode
        )

        if (500..<600).contains(statusCode) {
            return .serverError(protocolError)
        }
        return .protocolError(protocolError)
    }

    func readImageFromDisk(localURL: URL, sourceUrl: String) -> Result<UIImage, MindboxError> {
        do {
            let imageData = try Data(contentsOf: localURL)
            guard let image = ImageFormat.getImage(imageData: imageData) else {
                Logger.common(message: "Inapps image is incorrect. [URL]: \(localURL)", level: .debug, category: .inAppMessages)
                let error = NSError(domain: "", code: NSURLErrorCannotDecodeContentData, userInfo: nil)
                return .failure(.unknown(error))
            }

            Logger.common(message: "Image is loaded successfully. [URL]: \(sourceUrl)", level: .debug, category: .inAppMessages)
            return .success(image)
        } catch {
            Logger.common(message: "Failed to read image data. Error: \(error.localizedDescription)", level: .debug, category: .inAppMessages)
            return .failure(.unknown(error))
        }
    }
}
