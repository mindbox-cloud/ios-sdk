//
//  MockUNAuthorizationStatusProvider.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 09.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications
@testable import Mindbox

final class MockUNAuthorizationStatusProvider: UNAuthorizationStatusProviding {

    func getStatus(result: @escaping (Bool) -> Void) {
        result(status.rawValue == UNAuthorizationStatus.authorized.rawValue)
    }

    private let status: UNAuthorizationStatus

    init(status: UNAuthorizationStatus) {
        self.status = status
    }
}

final class CyclicUNAuthorizationStatusProvider: UNAuthorizationStatusProviding {
    private let sequence: [UNAuthorizationStatus]
    private var index = 0

    init(sequence: [UNAuthorizationStatus]) {
        precondition(!sequence.isEmpty, "Sequence must not be empty")
        self.sequence = sequence
    }

    func getStatus(result: @escaping (Bool) -> Void) {
        let current = sequence[index % sequence.count]
        index += 1

        var granted: [UNAuthorizationStatus] = [.authorized]
        if #available(iOS 12.0, *) { granted.append(.provisional) }
        result(granted.contains(current))
    }
}
