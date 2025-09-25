//
//  EventGenerator.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

struct EventGenerator {

    func generateEvent() -> Event {
        Event(
            type: .installed,
            body: UUID().uuidString
        )
    }

    func generateEvents(count: Int) -> [Event] {
        return (1...count).map { _ in
            return Event(
                type: .customEvent,
                body: UUID().uuidString
            )
        }
    }

    func generateMockEvents(count: Int) -> [MockEvent] {
        return (1...count).map { _ in
            return MockEvent(
                type: .installed,
                body: UUID().uuidString,
                retryTimestamp: 100
            )
        }
    }
}
