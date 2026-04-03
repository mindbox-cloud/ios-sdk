//
//  MBNetworkFetcherResponseHandlingTests.swift
//  MindboxTests
//
//  Created on 2026-04-02.
//

import XCTest
@testable import Mindbox

final class MBNetworkFetcherResponseHandlingTests: XCTestCase {

    // MARK: - Setup

    private func makeFetcher() throws -> MBNetworkFetcher {
        let persistenceStorage = MockPersistenceStorage()
        persistenceStorage.configuration = try MBConfiguration(
            endpoint: "test-endpoint",
            domain: "api.mindbox.ru"
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return MBNetworkFetcher(persistenceStorage: persistenceStorage, session: session)
    }

    private func stubResponse(statusCode: Int, body: Data? = nil) {
        StubURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, body)
        }
    }

    private func baseResponseData(status: String) -> Data {
        // swiftlint:disable:next force_try
        try! JSONSerialization.data(withJSONObject: ["status": status])
    }

    private func protocolErrorData(status: String, message: String, httpCode: Int) -> Data {
        // swiftlint:disable:next force_try
        try! JSONSerialization.data(withJSONObject: [
            "status": status,
            "errorMessage": message,
            "httpStatusCode": httpCode
        ])
    }

    private func validationErrorData() -> Data {
        // swiftlint:disable:next force_try
        try! JSONSerialization.data(withJSONObject: [
            "status": "ValidationError",
            "validationMessages": [
                ["message": "Invalid email", "location": "/customer/email"]
            ]
        ])
    }

    // MARK: - 2xx + Success status → success

    func test_http200_statusSuccess_returnsSuccess() throws {
        let fetcher = try makeFetcher()
        let body = baseResponseData(status: "Success")
        stubResponse(statusCode: 200, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                break // expected
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 2xx + TransactionAlreadyProcessed → success

    func test_http200_statusTransactionAlreadyProcessed_returnsSuccess() throws {
        let fetcher = try makeFetcher()
        let body = baseResponseData(status: "TransactionAlreadyProcessed")
        stubResponse(statusCode: 200, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                break // expected
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 2xx + ValidationError → .validationError

    func test_http200_statusValidationError_returnsValidationError() throws {
        let fetcher = try makeFetcher()
        let body = validationErrorData()
        stubResponse(statusCode: 200, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected validationError")
            case .failure(let error):
                guard case .validationError = error else {
                    XCTFail("Expected validationError, got \(error)")
                    expectation.fulfill()
                    return
                }
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 4xx + status "Success" in body → protocolError (NOT success)

    func test_http400_statusSuccess_returnsProtocolError() throws {
        let fetcher = try makeFetcher()
        let body = baseResponseData(status: "Success")
        stubResponse(statusCode: 400, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("HTTP 400 with Success status should NOT be treated as success")
            case .failure(let error):
                guard case .protocolError = error else {
                    XCTFail("Expected protocolError, got \(error)")
                    expectation.fulfill()
                    return
                }
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 400 + ProtocolError → .protocolError

    func test_http400_statusProtocolError_returnsProtocolError() throws {
        let fetcher = try makeFetcher()
        let body = protocolErrorData(status: "ProtocolError", message: "Bad request", httpCode: 400)
        stubResponse(statusCode: 400, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected protocolError")
            case .failure(let error):
                guard case .protocolError(let pe) = error else {
                    XCTFail("Expected protocolError, got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(pe.httpStatusCode, 400)
                XCTAssertEqual(pe.errorMessage, "Bad request")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 404 with unparseable body → protocolError "Invalid request url"

    func test_http404_unparseableBody_returnsProtocolErrorInvalidUrl() throws {
        let fetcher = try makeFetcher()
        let body = "not json".data(using: .utf8)
        stubResponse(statusCode: 404, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected protocolError for 404")
            case .failure(let error):
                guard case .protocolError(let pe) = error else {
                    XCTFail("Expected protocolError, got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(pe.httpStatusCode, 404)
                XCTAssertEqual(pe.errorMessage, "Invalid request url")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 429 + ProtocolError → .protocolError

    func test_http429_statusProtocolError_returnsProtocolError() throws {
        let fetcher = try makeFetcher()
        let body = protocolErrorData(status: "ProtocolError", message: "Rate limit exceeded", httpCode: 429)
        stubResponse(statusCode: 429, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected protocolError")
            case .failure(let error):
                guard case .protocolError(let pe) = error else {
                    XCTFail("Expected protocolError, got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(pe.httpStatusCode, 429)
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 5xx + InternalServerError body → .serverError with decoded body

    func test_http500_statusInternalServerError_returnsServerError() throws {
        let fetcher = try makeFetcher()
        let body = protocolErrorData(status: "InternalServerError", message: "Temporary unavailability", httpCode: 500)
        stubResponse(statusCode: 500, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected serverError")
            case .failure(let error):
                guard case .serverError(let pe) = error else {
                    XCTFail("Expected serverError, got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(pe.httpStatusCode, 500)
                XCTAssertEqual(pe.errorMessage, "Temporary unavailability")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 502 with no status body → .serverError (generic)

    func test_http502_noStatusBody_returnsServerError() throws {
        let fetcher = try makeFetcher()
        let body = "Bad Gateway".data(using: .utf8)
        stubResponse(statusCode: 502, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected serverError")
            case .failure(let error):
                guard case .serverError(let pe) = error else {
                    XCTFail("Expected serverError, got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(pe.httpStatusCode, 502)
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 2xx + decode failure + emptyData → success

    func test_http200_decodeFail_emptyDataTrue_returnsSuccess() throws {
        let fetcher = try makeFetcher()
        let body = "not json".data(using: .utf8)
        stubResponse(statusCode: 200, body: body)

        let expectation = expectation(description: "completion")
        // Void request uses emptyData=true internally
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                break // expected — emptyData=true swallows decode errors at 2xx
            case .failure(let error):
                XCTFail("Expected success with emptyData=true at 2xx, got \(error)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - needBaseResponse=false + HTTP 4xx → protocolError (NOT success)

    func test_needBaseResponseFalse_http403_returnsProtocolError() throws {
        let fetcher = try makeFetcher()
        let body = "Forbidden".data(using: .utf8)
        stubResponse(statusCode: 403, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(type: InAppGeoResponse.self, route: FetchInAppGeoRoute(), needBaseResponse: false) { result in
            switch result {
            case .success:
                XCTFail("needBaseResponse=false + HTTP 403 should NOT be success")
            case .failure(let error):
                guard case .protocolError(let pe) = error else {
                    XCTFail("Expected protocolError, got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(pe.httpStatusCode, 403)
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - needBaseResponse=false + HTTP 2xx → success

    func test_needBaseResponseFalse_http200_returnsSuccess() throws {
        let fetcher = try makeFetcher()
        let model = InAppGeoResponse(city: 1, region: 2, country: 3)
        let body = try JSONEncoder().encode(model)
        stubResponse(statusCode: 200, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(type: InAppGeoResponse.self, route: FetchInAppGeoRoute(), needBaseResponse: false) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.city, 1)
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 3xx → invalidResponse

    func test_http301_returnsInvalidResponse() throws {
        let fetcher = try makeFetcher()
        let body = Data()
        stubResponse(statusCode: 301, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected invalidResponse for 3xx")
            case .failure(let error):
                guard case .invalidResponse = error else {
                    XCTFail("Expected invalidResponse, got \(error)")
                    expectation.fulfill()
                    return
                }
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 2xx + ProtocolError status in body → invalidResponse

    func test_http200_statusProtocolError_returnsInvalidResponse() throws {
        let fetcher = try makeFetcher()
        let body = baseResponseData(status: "ProtocolError")
        stubResponse(statusCode: 200, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected invalidResponse for 2xx + ProtocolError status")
            case .failure(let error):
                guard case .invalidResponse = error else {
                    XCTFail("Expected invalidResponse, got \(error)")
                    expectation.fulfill()
                    return
                }
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 2xx + InternalServerError status in body → invalidResponse

    func test_http200_statusInternalServerError_returnsInvalidResponse() throws {
        let fetcher = try makeFetcher()
        let body = baseResponseData(status: "InternalServerError")
        stubResponse(statusCode: 200, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected invalidResponse for 2xx + InternalServerError status")
            case .failure(let error):
                guard case .invalidResponse = error else {
                    XCTFail("Expected invalidResponse, got \(error)")
                    expectation.fulfill()
                    return
                }
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 2xx + unknown status in body → invalidResponse

    func test_http200_statusUnknown_returnsInvalidResponse() throws {
        let fetcher = try makeFetcher()
        let body = baseResponseData(status: "SomethingUnexpected")
        stubResponse(statusCode: 200, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected invalidResponse for 2xx + unknown status")
            case .failure(let error):
                guard case .invalidResponse = error else {
                    XCTFail("Expected invalidResponse, got \(error)")
                    expectation.fulfill()
                    return
                }
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 4xx + ValidationError status → .validationError

    func test_http400_statusValidationError_returnsValidationError() throws {
        let fetcher = try makeFetcher()
        let body = validationErrorData()
        stubResponse(statusCode: 400, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected validationError")
            case .failure(let error):
                guard case .validationError = error else {
                    XCTFail("Expected validationError, got \(error)")
                    expectation.fulfill()
                    return
                }
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 4xx (non-404) + unparseable body → protocolError "Client error"

    func test_http400_unparseableBody_returnsProtocolErrorClientError() throws {
        let fetcher = try makeFetcher()
        let body = "not json".data(using: .utf8)
        stubResponse(statusCode: 400, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected protocolError for 400 + unparseable body")
            case .failure(let error):
                guard case .protocolError(let pe) = error else {
                    XCTFail("Expected protocolError, got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(pe.httpStatusCode, 400)
                XCTAssertEqual(pe.errorMessage, "Client error")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 403 + unparseable body → protocolError "Client error"

    func test_http403_unparseableBody_returnsProtocolErrorClientError() throws {
        let fetcher = try makeFetcher()
        let body = "Forbidden".data(using: .utf8)
        stubResponse(statusCode: 403, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected protocolError for 403 + unparseable body")
            case .failure(let error):
                guard case .protocolError(let pe) = error else {
                    XCTFail("Expected protocolError, got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(pe.httpStatusCode, 403)
                XCTAssertEqual(pe.errorMessage, "Client error")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 5xx + empty body → .serverError

    func test_http500_emptyBody_returnsServerError() throws {
        let fetcher = try makeFetcher()
        stubResponse(statusCode: 500, body: nil)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected serverError for 500 + nil data")
            case .failure(let error):
                guard case .serverError(let pe) = error else {
                    XCTFail("Expected serverError, got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(pe.httpStatusCode, 500)
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 2xx + empty body + Void request (emptyData=true) → success

    func test_http200_emptyBody_voidRequest_returnsSuccess() throws {
        let fetcher = try makeFetcher()
        stubResponse(statusCode: 200, body: nil)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                break // expected — emptyData=true at 2xx tolerates unparseable body
            case .failure(let error):
                XCTFail("Expected success for 200 + empty body + Void request, got \(error)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 2xx + empty body + typed request (emptyData=false) → parsing error

    func test_http200_emptyBody_typedRequest_returnsParsingError() throws {
        let fetcher = try makeFetcher()
        stubResponse(statusCode: 200, body: nil)

        let expectation = expectation(description: "completion")
        fetcher.request(type: InAppGeoResponse.self, route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected parsing error for 200 + empty body + typed request")
            case .failure(let error):
                guard case .internalError(let ie) = error else {
                    XCTFail("Expected internalError(.parsing), got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(ie.errorKey, ErrorKey.parsing.rawValue)
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - 503 + parseable body → .serverError with decoded message

    func test_http503_parseableBody_returnsServerErrorWithMessage() throws {
        let fetcher = try makeFetcher()
        let body = protocolErrorData(status: "InternalServerError", message: "Service Unavailable", httpCode: 503)
        stubResponse(statusCode: 503, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected serverError")
            case .failure(let error):
                guard case .serverError(let pe) = error else {
                    XCTFail("Expected serverError, got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(pe.httpStatusCode, 503)
                XCTAssertEqual(pe.errorMessage, "Service Unavailable")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Typed request + 200 + needBaseResponse=true + success body → decoded object

    func test_typedRequest_http200_statusSuccess_returnsDecodedObject() throws {
        let fetcher = try makeFetcher()
        let responseBody: [String: Any] = [
            "status": "Success",
            "city_id": 10,
            "region_id": 20,
            "country_id": 30
        ]
        // swiftlint:disable:next force_try
        let body = try! JSONSerialization.data(withJSONObject: responseBody)
        stubResponse(statusCode: 200, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(type: InAppGeoResponse.self, route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.city, 10)
                XCTAssertEqual(response.region, 20)
                XCTAssertEqual(response.country, 30)
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Typed request + 200 + valid base response but invalid target type → parsing error

    func test_typedRequest_http200_invalidTargetType_returnsParsingError() throws {
        let fetcher = try makeFetcher()
        // Valid base response but missing fields for InAppGeoResponse
        let body = baseResponseData(status: "Success")
        stubResponse(statusCode: 200, body: body)

        let expectation = expectation(description: "completion")
        fetcher.request(type: InAppGeoResponse.self, route: FetchInAppGeoRoute()) { result in
            switch result {
            case .success:
                XCTFail("Expected parsing error for invalid target type")
            case .failure(let error):
                guard case .internalError(let ie) = error else {
                    XCTFail("Expected internalError(.parsing), got \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(ie.errorKey, ErrorKey.parsing.rawValue)
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }
}

// MARK: - Stub URL Protocol

private final class StubURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
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
