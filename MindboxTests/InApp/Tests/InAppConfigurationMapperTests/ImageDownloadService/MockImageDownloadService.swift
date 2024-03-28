//
//  MockImageDownloadService.swift
//  MindboxTests
//
//  Created by vailence on 16.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger
@testable import Mindbox

final class MockImageDownloadService: ImageDownloadServiceProtocol {
    func downloadImage(withUrl url: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        if url == "https://example.com/image.jpg" {
            completion(.success(UIImage()))
        } else {
            let error = NSError(domain: "", code: NSURLErrorCannotDecodeContentData, userInfo: nil)
            completion(.failure(error))
        }
    }
}
