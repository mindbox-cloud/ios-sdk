//
//  UtilsTest.swift
//  MindBoxTests
//
//  Created by Mikhail Barilov on 29.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import MindBox

class UtilsTest: XCTestCase {

    override func setUpWithError() throws {

        DIManager.shared.dropContainer()
        DIManager.shared.registerServices()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_checkUUID() throws {

        
    }

    func test_isValidURL() throws {
        let validURLs = [
            "https://www.google.com/search?rlz=1C5CHFA_enRU848RU848&ei=GMYTYIKCK9SSwPAP8cWjiAM&q=umbrella+it&oq=umbrella+it&gs_lcp=CgZwc3ktYWIQAzIICAAQxwEQrwEyCAgAEMcBEK8BMgIIADICCAAyAggAMggIABDHARCvATICCAA6BQgAELEDOggIABCxAxCDAToICAAQxwEQowI6BggAEAoQAToOCAAQxwEQrwEQChABECo6BAgAEAo6BAgAEB46CgguELEDEEMQkwI6BAgAEEM6BwguELEDEEM6CggAEMcBEK8BEAo6BwgAELEDEAo6CwgAELEDEMcBEKMCOgUILhCxAzoOCAAQsQMQgwEQxwEQowI6CggAEAoQARBDECo6BwgAELEDEENQolhYx7IBYM61AWgJcAB4AIABcIgBqA2SAQQxNi40mAEAoAEBqgEHZ3dzLXdperABAMABAQ&sclient=psy-ab&ved=0ahUKEwiC7tnL28DuAhVUCRAIHfHiCDEQ4dUDCA0&uact=5",
            "http://www.google.com"
        ]

        validURLs.forEach { (validUrl) in
            XCTAssertTrue( Utilities.isValidURL(string: validUrl))
        }

        let invalidURLs = [
            "",
            "https://www google com/",
            "www.google.com",
        ]

        invalidURLs.forEach { (invalidURL) in
            XCTAssertFalse( Utilities.isValidURL(string: invalidURL))
        }
    }

}
