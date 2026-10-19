//
//  FileManager+Extensions.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation

extension FileManager {

    enum StoreURLError: LocalizedError, Equatable {
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
