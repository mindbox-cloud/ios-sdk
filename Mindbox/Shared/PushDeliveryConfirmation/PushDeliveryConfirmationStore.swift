//
//  PushDeliveryConfirmationStore.swift
//  Mindbox
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Confirmations the extension could not get through, waiting in the App Group for the app.
///
/// One confirmation is one file, written atomically. Nothing here locks the file: the system may suspend
/// the extension at any moment, and a lock held in the shared container at that point gets it killed.
@_spi(Internal)
public struct PushDeliveryConfirmationStore: Sendable {

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// - Returns: `nil` when the App Group container is unavailable.
    public init?(appGroupIdentifier: String) {
        guard !appGroupIdentifier.isEmpty,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }
        self.init(directory: container.appendingPathComponent(Self.directoryName, isDirectory: true))
    }

    /// Before the first unlock after a restart the file cannot be written: the request still goes, without a backup.
    public func save(_ confirmation: PushDeliveryConfirmation) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try confirmation.encoded().write(
            to: fileURL(of: confirmation),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    public func remove(_ confirmation: PushDeliveryConfirmation) {
        try? FileManager.default.removeItem(at: fileURL(of: confirmation))
    }

    /// The waiting confirmations, oldest first.
    ///
    /// A file that cannot be decoded is removed. A file that cannot be read stays for a later call:
    /// before the first unlock after a restart the system keeps it closed.
    public func pending() -> [PushDeliveryConfirmation] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []

        return files
            .filter { $0.pathExtension == Self.fileExtension }
            .compactMap { file in
                guard let data = try? Data(contentsOf: file) else {
                    return nil
                }
                guard let confirmation = try? PushDeliveryConfirmation(encoded: data) else {
                    try? FileManager.default.removeItem(at: file)
                    return nil
                }
                return confirmation
            }
            .sorted { $0.receivedAt < $1.receivedAt }
    }

    private func fileURL(of confirmation: PushDeliveryConfirmation) -> URL {
        directory.appendingPathComponent(confirmation.fileName).appendingPathExtension(Self.fileExtension)
    }

    static let directoryName = "MindboxPushDeliveryConfirmations"
    static let fileExtension = "json"
}
