//
//  PushDeliveryConfirmer.swift
//  MindboxNotifications
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

final class PushDeliveryConfirmer: Sendable {

    private let sender: PushDeliveryConfirmationSender
    private let store: PushDeliveryConfirmationStore?

    init(
        sender: PushDeliveryConfirmationSender = PushDeliveryConfirmationSender(),
        store: PushDeliveryConfirmationStore? = PushDeliveryConfirmationStore()
    ) {
        self.sender = sender
        self.store = store
    }

    @discardableResult
    func start(_ confirmation: PushDeliveryConfirmation, completion: (@Sendable () -> Void)? = nil) -> Task<Void, Never> {
        try? store?.save(confirmation)
        return Task { [sender, store] in
            let statusCode = await sender.send(confirmation)
            if Self.closesConfirmation(statusCode) {
                store?.remove(confirmation)
            }
            completion?()
        }
    }

    static func closesConfirmation(_ statusCode: Int?) -> Bool {
        guard let statusCode else { return false }
        return (200..<300).contains(statusCode) || ((400..<500).contains(statusCode) && statusCode != 429)
    }
}
