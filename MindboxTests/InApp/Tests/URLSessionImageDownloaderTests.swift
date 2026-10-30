//
//  URLSessionImageDownloaderTests.swift
//  MindboxTests
//
//  Created by vailence on 15.05.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Testing
import XCTest
@testable import Mindbox

// swiftlint:disable force_unwrapping

class URLSessionImageDownloaderTests: XCTestCase {

    var imageDownloader: ImageDownloader!

    override func setUp() {
        super.setUp()
        imageDownloader = MockImageDownloader()
    }

    override func tearDown() {
        imageDownloader = nil
        super.tearDown()
    }

    func testSuccessfulImageDownload() {
        let imageUrl = "https://example.com/image.jpg"
        let expectation = XCTestExpectation(description: "Image download should succeed")

        let mockDownloader = MockImageDownloader()
        mockDownloader.expectedLocalURL = URL(fileURLWithPath: "/path/to/image.jpg")
        mockDownloader.expectedResponse = HTTPURLResponse(url: URL(string: imageUrl)!, statusCode: 200, httpVersion: nil, headerFields: nil)

        imageDownloader = mockDownloader
        imageDownloader.downloadImage(withUrl: imageUrl) { localURL, response, error in
            XCTAssertEqual(localURL, mockDownloader.expectedLocalURL, "Local URL should match the expected value")
            XCTAssertEqual(response?.statusCode, mockDownloader.expectedResponse?.statusCode, "Response status code should match the expected value")
            XCTAssertNil(error, "Error should be nil")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testTimeoutError() {
        let imageUrl = "https://example.com/slow-image.jpg"
        let expectation = XCTestExpectation(description: "Image download should timeout")

        let mockDownloader = MockImageDownloader()
        mockDownloader.expectedError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)

        imageDownloader = mockDownloader

        imageDownloader.downloadImage(withUrl: imageUrl) { localURL, _, error in
            XCTAssertNil(localURL, "Local URL should be nil")
            XCTAssertNotNil(error, "Error should not be nil")
            XCTAssertEqual((error as NSError?)?.code, NSURLErrorTimedOut, "Error code should be NSURLErrorTimedOut")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testNon200StatusCode() {
        let imageUrl = "https://example.com/non-existing-image.jpg"
        let expectation = XCTestExpectation(description: "Image download should fail with non-200 status code")

        let mockDownloader = MockImageDownloader()
        let non200Response = HTTPURLResponse(url: URL(string: imageUrl)!, statusCode: 404, httpVersion: nil, headerFields: nil)
        mockDownloader.expectedResponse = non200Response
        mockDownloader.expectedError = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: nil)

        imageDownloader = mockDownloader

        imageDownloader.downloadImage(withUrl: imageUrl) { localURL, response, error in
            XCTAssertNil(localURL, "Local URL should be nil")
            XCTAssertNotNil(response, "Response should not be nil")
            XCTAssertEqual(response?.statusCode, non200Response?.statusCode, "Response status code should match the expected value")
            XCTAssertNotNil(error, "Error should not be nil")
            XCTAssertEqual((error as NSError?)?.code, NSURLErrorBadServerResponse, "Error code should be NSURLErrorBadServerResponse")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testCorruptedImage() {
        let imageUrl = "https://example.com/corrupted-image.jpg"
        let expectation = XCTestExpectation(description: "Downloaded image should be corrupted")

        let mockDownloader = MockImageDownloader()
        let imageURL = URL(fileURLWithPath: "/path/to/image.jpg")
        mockDownloader.expectedLocalURL = imageURL
        mockDownloader.expectedResponse = HTTPURLResponse(url: URL(string: imageUrl)!, statusCode: 200, httpVersion: nil, headerFields: nil)

        imageDownloader = mockDownloader

        let corruptedImagePath = imageURL.path
        FileManager.default.createFile(atPath: corruptedImagePath, contents: Data(), attributes: nil)

        imageDownloader.downloadImage(withUrl: imageUrl) { localURL, response, error in
            XCTAssertNotNil(localURL, "Local URL should not be nil")
            XCTAssertNil(error, "Error should be nil")
            XCTAssertEqual(response?.statusCode, 200, "Response status code should be 200")

            if let localURL = localURL {
                let isCorrupted = self.isImageCorrupted(localURL)
                XCTAssertTrue(isCorrupted, "Downloaded image should be corrupted")
            } else {
                XCTFail("Failed to retrieve local URL")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func isImageCorrupted(_ imageURL: URL) -> Bool {
        if let image = UIImage(contentsOfFile: imageURL.path) {
            return image.cgImage == nil
        }

        return true
    }
}

@Suite("URLSessionImageDownloader session")
struct URLSessionImageDownloaderSessionTests {

    @Test("A download's session is invalidated once its task finishes")
    func sessionIsInvalidatedAfterTheDownload() async {
        let invalidation = SessionInvalidationSpy()
        let downloader = URLSessionImageDownloader(persistenceStorage: MockPersistenceStorage()) { configuration in
            configuration.protocolClasses = [ImageStubURLProtocol.self]
            return URLSession(configuration: configuration, delegate: invalidation, delegateQueue: nil)
        }

        let statusCode: Int? = await withCheckedContinuation { continuation in
            downloader.downloadImage(withUrl: "https://mindbox.invalid/image.png") { _, response, _ in
                continuation.resume(returning: response?.statusCode)
            }
        }
        let isInvalidated = await pollUntil(deadline: 2, value: { invalidation.isInvalidated }, condition: { $0 })

        #expect(statusCode == 200)
        #expect(isInvalidated)
    }
}

private final class SessionInvalidationSpy: NSObject, URLSessionDelegate {
    private let lock = NSLock()
    private var invalidated = false

    var isInvalidated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return invalidated
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        lock.lock()
        invalidated = true
        lock.unlock()
    }
}

private final class ImageStubURLProtocol: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data([0xFF, 0xD8, 0xFF]))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
