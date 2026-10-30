//
//  EmbeddedBlockPlaceMemory.swift
//  Mindbox
//
//  Created by vailence on 24.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

struct EmbeddedBlockPlaceRecord: Codable, Equatable {

    let rememberedAt: Date
}

protocol EmbeddedBlockPlaceRemembering: AnyObject {

    func hasShownContent(at place: String) -> Bool

    func rememberShownContent(at place: String)

    func forgetPlace(_ place: String)
}

final class EmbeddedBlockPlaceMemory: EmbeddedBlockPlaceRemembering {

    private let persistenceStorage: PersistenceStorage

    private let now: () -> Date

    private let lock = NSLock()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(persistenceStorage: PersistenceStorage, now: @escaping () -> Date = Date.init) {
        self.persistenceStorage = persistenceStorage
        self.now = now
    }

    func hasShownContent(at place: String) -> Bool {
        lock.withLock { persistenceStorage.embeddedBlockPlaceRecords?[place] != nil }
    }

    func rememberShownContent(at place: String) {
        lock.withLock {
            var records = persistenceStorage.embeddedBlockPlaceRecords ?? [:]

            guard records[place] == nil else { return }

            guard let data = try? encoder.encode(EmbeddedBlockPlaceRecord(rememberedAt: now())) else {
                Logger.common(message: "[EmbeddedBlock] Place '\(place)': could not encode its record — new automatic blocks here start hidden",
                              level: .error, category: .embeddedBlocks)
                return
            }

            records[place] = data
            persistenceStorage.embeddedBlockPlaceRecords = records

            Logger.common(message: "[EmbeddedBlock] Place '\(place)' showed content — remembered, new automatic blocks here start with a placeholder",
                          category: .embeddedBlocks)
        }
    }

    func forgetPlace(_ place: String) {
        lock.withLock {
            guard var records = persistenceStorage.embeddedBlockPlaceRecords, records.removeValue(forKey: place) != nil else { return }

            persistenceStorage.embeddedBlockPlaceRecords = records

            Logger.common(message: "[EmbeddedBlock] Place '\(place)' came out empty — forgotten, new automatic blocks here start hidden",
                          category: .embeddedBlocks)
        }
    }

    func record(at place: String) -> EmbeddedBlockPlaceRecord? {
        lock.withLock {
            guard let data = persistenceStorage.embeddedBlockPlaceRecords?[place] else { return nil }

            return try? decoder.decode(EmbeddedBlockPlaceRecord.self, from: data)
        }
    }
}
