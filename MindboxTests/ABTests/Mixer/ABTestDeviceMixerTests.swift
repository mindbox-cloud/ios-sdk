//
//  ABTestDeviceMixerTests.swift
//  MindboxTests
//
//  Created by vailence on 13.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class ABTestDeviceMixerTests: XCTestCase {
    
    var sut: ABTestDeviceMixer!

    override func setUp() {
        super.setUp()
        sut = ABTestDeviceMixer()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testModulusGuidHash() {
        let salt = "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1"
        let array = getArray(resourceName: "MixerUUIDS")
            
        for item in array {
            let components = item.components(separatedBy: " | ")
            guard components.count == 2,
                  let uuid = UUID(uuidString: components[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                  let result = Int(components[1].trimmingCharacters(in: .whitespacesAndNewlines))
            else {
                continue
            }
                
            if let modulusResult = sut.modulusGuidHash(identifier: uuid, salt: salt) {
                XCTAssertEqual(result, modulusResult)
            } else {
                XCTFail("Modulus result is nil")
            }
        }
    }

    private func getArray(resourceName: String) -> [String] {
        do {
            let bundle = Bundle(for: ABTestDeviceMixerTests.self)
            let fileURL = bundle.url(forResource: resourceName, withExtension: "json")!
            let data = try Data(contentsOf: fileURL)
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [String] {
                return jsonArray
            }
            return []
        } catch {
            return []
        }
    }
}
