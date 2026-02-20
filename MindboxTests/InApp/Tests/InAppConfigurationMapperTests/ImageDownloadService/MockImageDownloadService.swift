//
//  MockImageDownloadService.swift
//  MindboxTests
//
//  Created by vailence on 16.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
@testable import Mindbox

class MockImageDownloadService: ImageDownloadServiceProtocol {
    func downloadImage(withUrl url: String, completion: @escaping (Result<UIImage, MindboxError>) -> Void) {
        if url == "https://example.com/image.jpg" {
            completion(.success(UIImage()))
        } else {
            completion(
                .failure(
                    MindboxError.protocolError(
                        ProtocolError(
                            status: Status.protocolError,
                            errorMessage: "Mock image download failed",
                            httpStatusCode: 404
                        )
                    )
                )
            )
        }
    }
}
