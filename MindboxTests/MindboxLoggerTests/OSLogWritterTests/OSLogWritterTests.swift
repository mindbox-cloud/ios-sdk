//
//  OSLogWritterTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 02.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import XCTest

final class OSLogWritterTests: XCTestCase {

    let mock = OSLogWritterMock()

    override func setUpWithError() throws {
        mock.logLevel = nil
        mock.message = nil
    }

    override func tearDownWithError() throws {
        mock.logLevel = nil
        mock.message = nil
    }

    func test_log_writter() throws {
        mock.writeMessage("Hello world", logLevel: .info)
        XCTAssertEqual("Hello world", mock.message)
        XCTAssertEqual(.info, mock.logLevel)
    }
}
