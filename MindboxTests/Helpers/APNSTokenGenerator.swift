//
//  APNSTokenGenerator.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 09.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

// swiftlint:disable force_unwrapping

struct APNSTokenGenerator {

    func generate() -> Data {
        (1...8)
            .map { _ in randomString(length: 8) + " " }
            .reduce("", +)
            .data(using: .utf8)!
    }

    private func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
