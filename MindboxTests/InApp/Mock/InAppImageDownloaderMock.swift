//
//  InAppImageDownloaderMock.swift
//  MindboxTests
//
//  Created by vailence on 15.05.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

class MockImageDownloader: ImageDownloader {
    var expectedLocalURL: URL?
    var expectedResponse: HTTPURLResponse?
    var expectedError: Error?

    func downloadImage(withUrl imageUrl: String, completion: @escaping (URL?, HTTPURLResponse?, Error?) -> Void) {
        completion(expectedLocalURL, expectedResponse, expectedError)
    }

    func cancel() {
    }
}
