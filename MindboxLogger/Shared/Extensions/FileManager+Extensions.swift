//
//  FileManager+Extensions.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation

extension FileManager {
    static func storeURL(for appGroup: String, databaseName: String) -> URL {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            fatalError("Container couldn't be created, please set up your AppGroup correctly. It must be the same for all your targets.")
        }

        return fileContainer.appendingPathComponent("\(databaseName).sqlite")
    }
}
