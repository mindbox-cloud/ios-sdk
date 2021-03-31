//
//  ValidatorsTestCase.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import Mindbox

class ValidatorsTestCase: XCTestCase {

    func testURLValidator() {
        [
            "https://www.google.com/search?rlz=1C5CHFA_enRU848RU848&ei=GMYTYIKCK9SSwPAP8cWjiAM&q=umbrella+it&oq=umbrella+it&gs_lcp=CgZwc3ktYWIQAzIICAAQxwEQrwEyCAgAEMcBEK8BMgIIADICCAAyAggAMggIABDHARCvATICCAA6BQgAELEDOggIABCxAxCDAToICAAQxwEQowI6BggAEAoQAToOCAAQxwEQrwEQChABECo6BAgAEAo6BAgAEB46CgguELEDEEMQkwI6BAgAEEM6BwguELEDEEM6CggAEMcBEK8BEAo6BwgAELEDEAo6CwgAELEDEMcBEKMCOgUILhCxAzoOCAAQsQMQgwEQxwEQowI6CggAEAoQARBDECo6BwgAELEDEENQolhYx7IBYM61AWgJcAB4AIABcIgBqA2SAQQxNi40mAEAoAEBqgEHZ3dzLXdperABAMABAQ&sclient=psy-ab&ved=0ahUKEwiC7tnL28DuAhVUCRAIHfHiCDEQ4dUDCA0&uact=5",
            
            "http://www.google.com"
        ]
        .compactMap({ URL(string: $0) })
        .forEach {
            XCTAssertTrue(URLValidator(url: $0).evaluate())
        }
        
        [
            "",
            
            "https://www google com/",
            
            "www.google.com",
        ]
        .compactMap { URL(string: $0) }
        .forEach {
            XCTAssertFalse(URLValidator(url: $0).evaluate())
        }
    }
    
    func testUDIDValidator() {
        XCTAssertFalse(UDIDValidator(udid: "00000000-0000-0000-0000-000000000000").evaluate())
        XCTAssertFalse(UDIDValidator(udid: "00000000-0000-0000-0000").evaluate())
        XCTAssertTrue(UDIDValidator(udid: "00000000-0000-0000-0000-000000000001").evaluate())
        (0...100)
            .map { _ in UUID().uuidString }
            .forEach { XCTAssertTrue(UDIDValidator(udid: $0).evaluate()) }
    }


}
