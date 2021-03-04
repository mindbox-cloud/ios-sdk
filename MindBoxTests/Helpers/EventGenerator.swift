//
//  EventGenerator.swift
//  MindBoxTests
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import MindBox

struct EventGenerator {

    func generateEvent() -> Event {
        Event(
            type: .installed,
            body: randomString()
        )
    }
        
    func generateEvents(count: Int) -> [Event] {
        return (1...count).map { _ in
            return Event(
                type: .installed,
                body: randomString()
            )
        }
    }

    private func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
}
