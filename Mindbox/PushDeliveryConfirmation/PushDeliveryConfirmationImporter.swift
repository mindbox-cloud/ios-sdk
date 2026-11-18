//
//  PushDeliveryConfirmationImporter.swift
//  Mindbox
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

/// Hands the confirmations the extension could not get through to guaranteed delivery.
final class PushDeliveryConfirmationImporter {

    private let store: PushDeliveryConfirmationStore?
    private let databaseRepository: DatabaseRepositoryProtocol

    init(store: PushDeliveryConfirmationStore?, databaseRepository: DatabaseRepositoryProtocol) {
        self.store = store
        self.databaseRepository = databaseRepository
    }

    /// A file leaves the App Group only once its event is in the queue; otherwise it waits for the next call.
    func importPending() {
        guard let store else { return }
        for confirmation in store.pending() {
            guard let data = try? confirmation.encoded(), let body = String(data: data, encoding: .utf8) else {
                continue
            }
            do {
                try databaseRepository.create(event: Event(type: .pushDeliveryConfirmation, body: body))
                store.remove(confirmation)
            } catch {
                continue
            }
        }
    }
}
