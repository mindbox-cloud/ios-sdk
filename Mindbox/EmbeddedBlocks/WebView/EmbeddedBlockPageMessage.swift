//
//  EmbeddedBlockPageMessage.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import CoreGraphics
import Foundation

/// What the embedded block page reports to the native side.
///
/// The core parses only the core layer — `ready`, `heightChanged` and `empty`, which every block
/// needs. Everything else with a valid envelope goes to the mechanic as an `action`: the core does
/// not know, and must not know, the vocabulary of a particular mechanic.
///
/// The format is our own and minimal for now: the page sends `{"type": ..., ...}`. Converging with
/// the shared in-app JS bridge (`MindboxWebBridge`) is a separate task; until then this parsing does
/// not need to be touched.
enum EmbeddedBlockPageMessage: Equatable {

    /// The page has rendered and asks the container to become `height` points tall.
    case ready(height: CGFloat)

    /// The page re-measured itself after it was shown — for example, more content was loaded.
    case heightChanged(height: CGFloat)

    /// The page has nothing to show — for example, the block is turned off in the admin panel. This
    /// is not an error.
    case empty

    /// An action beyond the core layer — its meaning is known to the block mechanic.
    case action(EmbeddedBlockPageAction)

    /// The message body arrives from WebKit as `Any`. A string is parsed as JSON, a dictionary is
    /// taken as is: the page may send either one, and there is no reason to fail on the message
    /// shape here.
    init?(body: Any) {
        let payload: [String: Any]

        if let dictionary = body as? [String: Any] {
            payload = dictionary
        } else if let json = body as? String,
                  let data = json.data(using: .utf8),
                  let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload = decoded
        } else {
            return nil
        }

        guard let type = payload["type"] as? String else {
            return nil
        }

        switch type {
        case "ready":
            guard let height = EmbeddedBlockPageMessage.height(from: payload) else { return nil }
            self = .ready(height: height)
        case "heightChanged":
            guard let height = EmbeddedBlockPageMessage.height(from: payload) else { return nil }
            self = .heightChanged(height: height)
        case "empty":
            self = .empty
        default:
            self = .action(EmbeddedBlockPageAction(type: type, payload: payload))
        }
    }

    /// JS gives a number as a `Double`, but whole values may also arrive as an `Int` — take both.
    private static func height(from payload: [String: Any]) -> CGFloat? {
        if let height = payload["height"] as? Double {
            return CGFloat(height)
        }

        if let height = payload["height"] as? Int {
            return CGFloat(height)
        }

        return nil
    }
}

/// The envelope of an action the core does not parse but passes to the mechanic: the type and the
/// whole message payload as is.
struct EmbeddedBlockPageAction: Equatable {

    let type: String
    let payload: [String: Any]

    static func == (lhs: EmbeddedBlockPageAction, rhs: EmbeddedBlockPageAction) -> Bool {
        lhs.type == rhs.type && (lhs.payload as NSDictionary).isEqual(to: rhs.payload)
    }
}
