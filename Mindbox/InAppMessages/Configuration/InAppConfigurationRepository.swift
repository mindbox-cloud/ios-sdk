//
//  InAppConfigurationRepository.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

/// Stores in-app messages configuration
class InAppConfigurationRepository {
    func fetchConfigFromCache() -> Data? {
        guard FileManager.default.fileExists(atPath: inAppConfigFileUrl.path) else {
            Log("Config file doesn't exist on a disk")
                .category(.inAppMessages).level(.debug).make()
            return nil
        }
        Log("Config file exists on a disk")
            .category(.inAppMessages).level(.debug).make()
        do {
            let data = try Data(contentsOf: inAppConfigFileUrl)
            Log("Successfuly load config file from disk")
                .category(.inAppMessages).level(.debug).make()
            return data
        } catch {
            Log("Failed to load config file from disk")
                .category(.inAppMessages).level(.debug).make()
            return nil
        }
    }

    func saveConfigToCache(_ data: Data) {
        do {
            try data.write(to: inAppConfigFileUrl)
            Log("Successfuly saved config file on a disk.")
                .category(.inAppMessages).level(.debug).make()
        } catch {
            Log("Failed to save config file on a disk. Error: \(error.localizedDescription)")
                .category(.inAppMessages).level(.debug).make()
        }
    }

    func clean() {
        guard FileManager.default.fileExists(atPath: inAppConfigFileUrl.path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: inAppConfigFileUrl)
        } catch {
            Log("Failed to clean inapp config cache. Error: \(error.localizedDescription)")
                .category(.inAppMessages).level(.error).make()
        }
    }

    private var inAppConfigFileUrl: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("InAppMessagesConfiguration.json")
    }

}
