//
//  InAppConfigurationRepository.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import MindboxLogger

/// Stores in-app messages configuration
class InAppConfigurationRepository {
    func fetchConfigFromCache() -> Data? {
        guard FileManager.default.fileExists(atPath: inAppConfigFileUrl.path) else {
            Logger.common(message: "Config file doesn't exist on a disk", level: .debug, category: .inAppMessages)
            return nil
        }
        Logger.common(message: "Config file exists on a disk", level: .debug, category: .inAppMessages)
        do {
            let data = try Data(contentsOf: inAppConfigFileUrl)
            Logger.common(message: "Successfuly load config file from disk", level: .debug, category: .inAppMessages)
            return data
        } catch {
            Logger.common(message: "Failed to load config file from disk", level: .debug, category: .inAppMessages)
            return nil
        }
    }

    func saveConfigToCache(_ data: Data) {
        do {
            try data.write(to: inAppConfigFileUrl)
            Logger.common(message: "Successfuly saved config file on a disk.", level: .debug, category: .inAppMessages)
        } catch {
            Logger.common(message: "Failed to save config file on a disk. Error: \(error.localizedDescription)", level: .debug, category: .inAppMessages)
        }
    }

    func clean() {
        guard FileManager.default.fileExists(atPath: inAppConfigFileUrl.path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: inAppConfigFileUrl)
        } catch {
            Logger.common(message: "Failed to clean inapp config cache. Error: \(error.localizedDescription)", level: .debug, category: .inAppMessages)
        }
    }

    private var inAppConfigFileUrl: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("InAppMessagesConfiguration.json")
    }
}
