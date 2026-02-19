//
//  GeoServiceTests.swift
//  MindboxTests
//
//  Created by vailence on 13.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable force_try

final class GeoServiceTests: XCTestCase {

    var sut: GeoServiceProtocol!
    var networkFetcher: MockNetworkFetcher!
    var targetingChecker: InAppTargetingCheckerProtocol!

    override func setUp() {
        super.setUp()
        networkFetcher = DI.injectOrFail(NetworkFetcher.self) as? MockNetworkFetcher
        targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
        sut = DI.injectOrFail(GeoServiceProtocol.self)
    }

    override func tearDown() {
        sut = nil
        networkFetcher = nil
        targetingChecker = nil
        MockGeoURLProtocol.requestHandler = nil
        SessionTemporaryStorage.shared.erase()
        super.tearDown()
    }

    func test_geo_request_valid() throws {
        let model = InAppGeoResponse(city: 1, region: 2, country: 3)
        let responseData = try! JSONEncoder().encode(model)
        var result: InAppGeoResponse?
        networkFetcher.data = responseData

        let expectations = expectation(description: "test_geo_request")

        sut.geoRequest { geoResult in
            if case .success(let response) = geoResult {
                result = response
            }
            expectations.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(result, model)
    }

    func test_geo_request_geoRequestCompleted() throws {
        let model = InAppGeoResponse(city: 1, region: 2, country: 3)
        let responseData = try! JSONEncoder().encode(model)
        var result: InAppGeoResponse?
        networkFetcher.data = responseData
        SessionTemporaryStorage.shared.geoRequestResult = .success(nil)

        let expectations = expectation(description: "test_geo_request")

        sut.geoRequest { geoResult in
            if case .success(let response) = geoResult {
                result = response
            }
            expectations.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertNil(result)
    }

    func test_geo_request_withMBNetworkFetcher_success() throws {
        let model = InAppGeoResponse(city: 1, region: 2, country: 3)
        let responseData = try JSONEncoder().encode(model)
        let fetcher = try makeMBNetworkFetcher()
        sut = GeoService(fetcher: fetcher, targetingChecker: targetingChecker)

        MockGeoURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, responseData)
        }

        let expectation = expectation(description: "geo request with MBNetworkFetcher should succeed")
        var result: InAppGeoResponse?

        sut.geoRequest { geoResult in
            if case .success(let response) = geoResult {
                result = response
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(result, model)
    }

    func test_geo_request_withMBNetworkFetcher_5xx_returnsNil() throws {
        let model = InAppGeoResponse(city: 1, region: 2, country: 3)
        let responseData = try JSONEncoder().encode(model)
        let fetcher = try makeMBNetworkFetcher()
        sut = GeoService(fetcher: fetcher, targetingChecker: targetingChecker)

        MockGeoURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, responseData)
        }

        let expectation = expectation(description: "geo request with MBNetworkFetcher should fail for 5xx")
        var result: InAppGeoResponse?

        sut.geoRequest { geoResult in
            if case .success(let response) = geoResult {
                result = response
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertNil(result)
    }

    func test_geo_fetcher_request_5xx_returnsServerError() throws {
        let model = InAppGeoResponse(city: 1, region: 2, country: 3)
        let responseData = try JSONEncoder().encode(model)
        let fetcher = try makeMBNetworkFetcher()

        MockGeoURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, responseData)
        }

        let expectation = expectation(description: "MBNetworkFetcher should map 5xx to serverError")
        fetcher.request(type: InAppGeoResponse.self, route: FetchInAppGeoRoute(), needBaseResponse: false) { result in
            switch result {
            case .success:
                XCTFail("Expected failure for HTTP 5xx")
            case .failure(let error):
                guard case .serverError(let protocolError) = error else {
                    XCTFail("Expected serverError, got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(protocolError.httpStatusCode, 500)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1)
    }

    func test_geo_request_withMBNetworkFetcher_5xx_returnsFailureServerError() throws {
        let model = InAppGeoResponse(city: 1, region: 2, country: 3)
        let responseData = try JSONEncoder().encode(model)
        let fetcher = try makeMBNetworkFetcher()
        sut = GeoService(fetcher: fetcher, targetingChecker: targetingChecker)

        MockGeoURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, responseData)
        }

        let expectation = expectation(description: "geo request should return serverError result")
        var receivedError: MindboxError?

        sut.geoRequest { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        guard case .serverError(let protocolError) = receivedError else {
            XCTFail("Expected serverError")
            return
        }
        XCTAssertEqual(protocolError.httpStatusCode, 500)
    }

    func test_geo_request_whenPreviousRequestFailed_returnsCachedFailure() {
        networkFetcher.error = .serverError(.init(status: .internalServerError, errorMessage: "Internal Server error", httpStatusCode: 500))
        let expectation = expectation(description: "geo request cached failure")
        expectation.expectedFulfillmentCount = 2
        var firstError: MindboxError?
        var secondError: MindboxError?

        sut.geoRequest { result in
            if case .failure(let error) = result {
                firstError = error
            }
            expectation.fulfill()
        }

        networkFetcher.error = nil
        sut.geoRequest { result in
            if case .failure(let error) = result {
                secondError = error
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        guard case .serverError(let firstProtocolError) = firstError else {
            XCTFail("Expected cached serverError on first call")
            return
        }
        guard case .serverError(let secondProtocolError) = secondError else {
            XCTFail("Expected cached serverError on second call")
            return
        }

        XCTAssertEqual(firstProtocolError.httpStatusCode, 500)
        XCTAssertEqual(secondProtocolError.httpStatusCode, 500)
    }

    func test_geo_request_whenPreviousRequestSucceeded_returnsCachedSuccess() throws {
        let model = InAppGeoResponse(city: 1, region: 2, country: 3)
        networkFetcher.data = try JSONEncoder().encode(model)
        let expectation = expectation(description: "geo request cached success")
        expectation.expectedFulfillmentCount = 2
        var firstResult: InAppGeoResponse?
        var secondResult: InAppGeoResponse?

        sut.geoRequest { result in
            if case .success(let response) = result {
                firstResult = response
            }
            expectation.fulfill()
        }

        networkFetcher.error = .serverError(.init(status: .internalServerError, errorMessage: "Internal Server error", httpStatusCode: 500))
        sut.geoRequest { result in
            if case .success(let response) = result {
                secondResult = response
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(firstResult, model)
        XCTAssertEqual(secondResult, model)
    }

    private func makeMBNetworkFetcher() throws -> MBNetworkFetcher {
        let persistenceStorage = MockPersistenceStorage()
        persistenceStorage.configuration = try MBConfiguration(
            endpoint: "test-endpoint",
            domain: "api.mindbox.ru"
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockGeoURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return MBNetworkFetcher(persistenceStorage: persistenceStorage, session: session)
    }
}

private final class MockGeoURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
