//
//  FileManager+Extensions.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation

extension FileManager {

    /// Error thrown when a shared App Group container cannot be resolved.
    enum StoreURLError: LocalizedError, Equatable {
        /// The App Group container for `appGroup` is unavailable — typically a missing,
        /// misconfigured, or unprovisioned App Group capability. (On a clean Simulator
        /// install the container has also been seen to resolve late, though that isn't
        /// documented.)
        case containerUnavailable(appGroup: String)

        var errorDescription: String? {
            switch self {
            case .containerUnavailable(let appGroup):
                return "App Group container '\(appGroup)' is unavailable. "
                    + "Set up your AppGroup correctly — it must be the same for all your targets. "
                    + "Read the documentation: https://developers.mindbox.ru/docs/ios-sdk-initialization"
            }
        }
    }

    static func storeURL(for appGroup: String, databaseName: String) throws -> URL {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            throw StoreURLError.containerUnavailable(appGroup: appGroup)
        }

        return fileContainer.appendingPathComponent("\(databaseName).sqlite")
    }
}
