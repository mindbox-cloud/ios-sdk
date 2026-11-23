//
//  Payload.swift
//  MindboxNotifications
//
//  Created by Ihor Kandaurov on 22.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

struct Payload {
    struct ImageURL: Codable {
        let imageUrl: String?
    }

    struct Button: Codable {
        struct Buttons: Codable {
            let text: String
            let uniqueKey: String
        }

        let uniqueKey: String

        let buttons: [Buttons]?

        let imageUrl: String?

        var debugDescription: String {
            "uniqueKey: \(uniqueKey)"
        }
    }

    struct Callbacks: Codable {
        struct URLs: Codable {
            let deliveredUrl: String?
        }

        let callbacks: URLs?
    }

    var withImageURL: ImageURL?
    var withButton: Button?
    var withCallbacks: Callbacks?
}
