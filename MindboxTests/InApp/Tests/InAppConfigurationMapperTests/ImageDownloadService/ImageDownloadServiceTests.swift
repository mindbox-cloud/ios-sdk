//
//  ImageDownloadServiceTests.swift
//  MindboxTests
//
//  Created by vailence on 16.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class ImageDownloadServiceTests: XCTestCase {
    var sut: ImageDownloadServiceProtocol!

    override func setUp() {
        super.setUp()
        sut = DI.injectOrFail(ImageDownloadServiceProtocol.self)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testDownloadImageSuccess() {
        let expectation = self.expectation(description: "Image download should succeed")

        sut.downloadImage(withUrl: "https://example.com/image.jpg") { result in
            switch result {
            case .success(let image):
                XCTAssertNotNil(image)
            case .failure(let error):
                XCTFail("Expected success, but got \(error) instead")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)
    }

    func testDownloadImageFailure() {
        let expectation = self.expectation(description: "Image download should fail")

        sut.downloadImage(withUrl: "https://example.com/invalid.jpg") { result in
            switch result {
            case .success(let image):
                XCTFail("Expected failure, but got \(image) instead")
            case .failure(let error):
                guard case .protocolError(let protocolError) = error else {
                    return XCTFail("Expected protocolError, got \(error)")
                }
                XCTAssertEqual(protocolError.httpStatusCode, 404)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)
    }
}
