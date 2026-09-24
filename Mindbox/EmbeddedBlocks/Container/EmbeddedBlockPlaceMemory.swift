//
//  EmbeddedBlockPlaceMemory.swift
//  Mindbox
//
//  Created by vailence on 24.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// What the SDK keeps about a place across launches. The record exists for as long as the place is
/// known to have shown content; a record is one value so that later fields — the measured height
/// among them — join it without a second key.
struct EmbeddedBlockPlaceRecord: Codable, Equatable {

    /// When the place was last written down as one that shows content.
    let rememberedAt: Date
}

/// Main-thread only: the container is the single reader and writer.
protocol EmbeddedBlockPlaceRemembering: AnyObject {

    /// Whether content was shown at the place on this device — what an `automatic` block starts from.
    func hasShownContent(at place: String) -> Bool

    /// The place showed content: it is worth a placeholder from now on.
    func rememberShownContent(at place: String)

    /// The place answered with nothing to show: the next block there starts as if it were new.
    func forgetPlace(_ place: String)
}

final class EmbeddedBlockPlaceMemory: EmbeddedBlockPlaceRemembering {

    private let persistenceStorage: PersistenceStorage

    private let now: () -> Date

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

    /// The presence of the record is the fact; what is inside is for the log and for later fields.
    func hasShownContent(at place: String) -> Bool {
        persistenceStorage.embeddedBlockPlaceRecords?[place] != nil
    }

    /// Written once: a block shows its content on every return to the screen, and each write is a
    /// synchronous round-trip to the app-group defaults on the main thread.
    func rememberShownContent(at place: String) {
        var records = persistenceStorage.embeddedBlockPlaceRecords ?? [:]

        guard records[place] == nil else { return }

        guard let data = try? encoder.encode(EmbeddedBlockPlaceRecord(rememberedAt: now())) else {
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': could not encode its record — the next launch starts it hidden again",
                          level: .error, category: .embeddedBlocks)
            return
        }

        records[place] = data
        persistenceStorage.embeddedBlockPlaceRecords = records

        Logger.common(message: "[EmbeddedBlock] Place '\(place)' showed content — remembered, the next launch starts it with a placeholder",
                      category: .embeddedBlocks)
    }

    func forgetPlace(_ place: String) {
        guard var records = persistenceStorage.embeddedBlockPlaceRecords, records.removeValue(forKey: place) != nil else { return }

        persistenceStorage.embeddedBlockPlaceRecords = records

        Logger.common(message: "[EmbeddedBlock] Place '\(place)' has nothing to show — forgotten, the next launch starts it hidden",
                      category: .embeddedBlocks)
    }

    func record(at place: String) -> EmbeddedBlockPlaceRecord? {
        guard let data = persistenceStorage.embeddedBlockPlaceRecords?[place] else { return nil }

        return try? decoder.decode(EmbeddedBlockPlaceRecord.self, from: data)
    }
}
