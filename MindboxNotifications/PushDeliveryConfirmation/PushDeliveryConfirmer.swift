//
//  PushDeliveryConfirmer.swift
//  MindboxNotifications
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

/// Tells Mindbox from the notification service extension that a push reached the device.
final class PushDeliveryConfirmer: Sendable {

    /// How long the push waits for the answer before it is shown.
    static let waitLimit = PushDeliveryConfirmation.extensionWaitLimit

    /// One per extension process, so pushes that come one after another reuse the connection.
    static let shared = PushDeliveryConfirmer()

    private let sender: PushDeliveryConfirmationSender
    private let store: PushDeliveryConfirmationStore?

    init(
        sender: PushDeliveryConfirmationSender = PushDeliveryConfirmationSender(timeout: PushDeliveryConfirmer.waitLimit),
        store: PushDeliveryConfirmationStore? = .hostAppGroup()
    ) {
        self.sender = sender
        self.store = store
    }

    /// Puts the confirmation on disk and starts sending it once.
    ///
    /// The file is written before this returns: the system may stop the extension at any moment,
    /// even right after the push is shown, and the app hands whatever is left to guaranteed delivery.
    /// - Returns: The send, which ends when the answer comes, no later than `waitLimit`.
    func start(_ confirmation: PushDeliveryConfirmation) -> Task<Void, Never> {
        try? store?.save(confirmation)
        return Task { [sender, store] in
            guard await sender.send(confirmation).isFinal else { return }
            store?.remove(confirmation)
        }
    }
}

extension PushDeliveryConfirmationStore {

    /// The store in the App Group the app reads.
    static func hostAppGroup(bundle: Bundle = .main) -> PushDeliveryConfirmationStore? {
        hostAppGroupIdentifier(bundle: bundle).flatMap(PushDeliveryConfirmationStore.init(appGroupIdentifier:))
    }

    /// `group.cloud.Mindbox.<bundle id of the host app>`, the App Group the SDK documents for the app and its extensions.
    static func hostAppGroupIdentifier(bundle: Bundle) -> String? {
        var hostBundle = bundle
        if bundle.bundleURL.pathExtension == "appex",
           let app = Bundle(url: bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()) {
            hostBundle = app
        }
        return hostBundle.bundleIdentifier.map { "group.cloud.Mindbox.\($0)" }
    }
}
