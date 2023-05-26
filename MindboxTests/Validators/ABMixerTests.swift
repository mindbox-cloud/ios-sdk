//
//  ABMixerTests.swift
//  MindboxTests
//
//  Created by vailence on 26.05.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class ABMixerTests: XCTestCase {
    
    var sut: CustomerAbMixer!

    override func setUp() {
        super.setUp()
        sut = CustomerAbMixer()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testModulusGuidHash() {
        let salt = "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1"
        let array = getArray(resourceName: "MixerUUIDS")
            
        var results: [Int] = []
        var modulusResults: [Int] = []

        for item in array {
            let components = item.components(separatedBy: " | ")
            guard components.count == 2,
                  let uuid = UUID(uuidString: components[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                  let result = Int(components[1].trimmingCharacters(in: .whitespacesAndNewlines))
            else {
                continue
            }
                
            results.append(result)
            let modulusResult = sut.modulusGuidHash(identifier: uuid, salt: salt)
            modulusResults.append(modulusResult)
        }
            
        XCTAssertEqual(results, modulusResults, "Results are not equal.")
    }

    private func getArray(resourceName: String) -> [String] {
        do {
            let bundle = Bundle(for: ABMixerTests.self)
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
