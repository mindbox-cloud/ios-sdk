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

    /// The extension writes the file, sends the confirmation and removes the file after a final answer.
    /// A younger file may still be on its way, so taking it would send the confirmation twice.
    /// One second on top covers writing and removing the file around the request.
    static let inFlightWindow = PushDeliveryConfirmation.extensionWaitLimit + 1

    private let store: PushDeliveryConfirmationStore?
    private let databaseRepository: DatabaseRepositoryProtocol

    init(store: PushDeliveryConfirmationStore?, databaseRepository: DatabaseRepositoryProtocol) {
        self.store = store
        self.databaseRepository = databaseRepository
    }

    /// A file leaves the App Group only once its event is in the queue; otherwise it waits for the next call.
    /// - Returns: How long to wait before calling again for the files the extension may still be sending,
    ///   or `nil` when there are none.
    @discardableResult
    func importPending(now: Date = Date()) -> TimeInterval? {
        guard let store else { return nil }
        var nextCall: TimeInterval?
        for confirmation in store.pending() {
            // A date in the future means the clock went back: the file is not in flight.
            let age = now.timeIntervalSince(confirmation.receivedAt)
            if age >= 0, age < Self.inFlightWindow {
                nextCall = min(nextCall ?? Self.inFlightWindow, Self.inFlightWindow - age)
                continue
            }
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
        return nextCall
    }
}
