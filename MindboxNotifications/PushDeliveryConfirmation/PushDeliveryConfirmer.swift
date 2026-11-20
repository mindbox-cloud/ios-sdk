//
//  PushDeliveryConfirmer.swift
//  MindboxNotifications
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

final class PushDeliveryConfirmer: Sendable {

    static let shared = PushDeliveryConfirmer()

    private let sender: PushDeliveryConfirmationSender
    private let store: PushDeliveryConfirmationStore?

    init(
        sender: PushDeliveryConfirmationSender = PushDeliveryConfirmationSender(),
        store: PushDeliveryConfirmationStore? = PushDeliveryConfirmationStore()
    ) {
        self.sender = sender
        self.store = store
    }

    func start(_ confirmation: PushDeliveryConfirmation) -> Task<Void, Never> {
        try? store?.save(confirmation)
        return Task { [sender, store] in
            let statusCode = await sender.send(confirmation)
            guard Self.closesConfirmation(statusCode) else { return }
            store?.remove(confirmation)
        }
    }

    static func closesConfirmation(_ statusCode: Int?) -> Bool {
        guard let statusCode else { return false }
        return (200..<300).contains(statusCode) || ((400..<500).contains(statusCode) && statusCode != 429)
    }
}
