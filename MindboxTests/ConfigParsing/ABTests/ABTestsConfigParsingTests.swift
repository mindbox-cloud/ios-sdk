//
//  ABTestsConfigParsingTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/12/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

fileprivate enum ABTestsConfig: String, Configurable {
    typealias DecodeType = [ABTest]

    case configWithABTests = "ABTestsConfig"

    case abTestsIdConfigError = "ABTestsIdConfigError"
    case abTestsIdConfigTypeError = "ABTestsIdConfigTypeError"

    case abTestsSdkVersionConfigError = "ABTestsSdkVersionConfigError"
    case abTestsSdkVersionConfigTypeError = "ABTestsSdkVersionConfigTypeError"
    
    case configWithABTestsNegativeLowerModulus = "ABTestsConfigNegativeLowerModulus"
    case configWithABTestsNegativeUpperModulus = "ABTestsConfigNegativeUpperModulus"
}

final class ABTestsConfigParsingTests: XCTestCase {

    func test_ABTestsConfig_shouldParseSuccessfully() throws {
        let config = try ABTestsConfig.configWithABTests.getConfig()
        XCTAssertEqual(config.count, 2)

        for abTest in config {
            XCTContext.runActivity(named: "Check abTest \(abTest) is in `config`") { _ in
                XCTAssertNotNil(abTest.salt)
                XCTAssertNotNil(abTest.sdkVersion)
                XCTAssertNotNil(abTest.variants)
            }
        }
    }

    func test_ABTestsConfig_withIdError_shouldThrowDecodingError() throws {
        XCTAssertThrowsError(try ABTestsConfig.abTestsIdConfigError.getConfig()) { error in
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    XCTAssertEqual(key.stringValue, "id")
                    XCTAssertEqual(context.debugDescription, "No value associated with key CodingKeys(stringValue: \"id\", intValue: nil) (\"id\").")
                default:
                    XCTFail("Unexpected DecodingError: \(error)")
                }
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func test_ABTestsConfig_withIdTypeError_shouldThrowDecodingError() throws {
        XCTAssertThrowsError(try ABTestsConfig.abTestsIdConfigTypeError.getConfig()) { error in
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    XCTAssertEqual(type is String.Type, true, "Expected type mismatch for String")
                    XCTAssertEqual(context.codingPath.map { $0.stringValue }.joined(separator: ", "), "Index 0, id")
                    XCTAssertEqual(context.debugDescription, "Expected to decode String but found number instead.")
                default:
                    XCTFail("Unexpected DecodingError: \(error)")
                }
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func test_ABTestsConfig_withSdkVersionError_shouldSetToNilCorruptedData() throws {
        let config = try ABTestsConfig.abTestsSdkVersionConfigError.getConfig()
        XCTAssertEqual(config.count, 2)

        for abTest in config {
            XCTContext.runActivity(named: "Check abTest \(abTest) is in `config`") { _ in
                if abTest.id == "94CD824A-59AA-4937-9E0E-089895A0DB6F" {
                    XCTAssertNil(abTest.sdkVersion)
                } else {
                    XCTAssertNotNil(abTest.sdkVersion)
                }
                XCTAssertNotNil(abTest.salt)
                XCTAssertNotNil(abTest.variants)
            }
        }
    }

    func test_ABTestsConfig_withSdkVersionTypeError_shouldThrowDecodingError() throws {
        XCTAssertThrowsError(try ABTestsConfig.abTestsSdkVersionConfigTypeError.getConfig()) { error in
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    XCTAssertEqual(type is Dictionary<String, Any>.Type, true, "Expected type mismatch for Dictionary<String, Any>")
                    XCTAssertEqual(context.codingPath.map { $0.stringValue }.joined(separator: ", "), "Index 0, sdkVersion")
                    XCTAssertEqual(context.debugDescription, "Expected to decode Dictionary<String, Any> but found number instead.")
                default:
                    XCTFail("Unexpected DecodingError: \(error)")
                }
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
    
    func test_ABTestsConfig_withNegative_Lower_Modulus_shouldThrowDecodingError() throws {
        XCTAssertThrowsError(try ABTestsConfig.configWithABTestsNegativeLowerModulus.getConfig()) { error in
            XCTAssertTrue(error is DecodingError)
            let errorDescription = String(describing: error)
            XCTAssertTrue(errorDescription.contains("Modulus lower value must be >= 0"))
        }
    }
    
    func test_ABTestsConfig_withNegative_Upper_Modulus_shouldThrowDecodingError() throws {
        XCTAssertThrowsError(try ABTestsConfig.configWithABTestsNegativeUpperModulus.getConfig()) { error in
            XCTAssertTrue(error is DecodingError)
            let errorDescription = String(describing: error)
            XCTAssertTrue(errorDescription.contains("Modulus upper value must be >= 0"))
        }
    }
}
