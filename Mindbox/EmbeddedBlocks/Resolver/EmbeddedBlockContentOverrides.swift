//
//  EmbeddedBlockContentOverrides.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Что подставить вместо контента, закреплённого за id блока.
protocol EmbeddedBlockContentOverriding: AnyObject {

    func resolution(for id: String) -> EmbeddedBlockResolution?
}

/// Отладочная подмена контента блока — то, чем приёмка воспроизводит сценарии, которые в сети не
/// выложены: пустой блок, молчащая страница, ответ уже после таймаута, незнакомое сообщение.
///
/// Подмена сидит на месте конфига, поэтому весь путь ниже — резолвер, провайдер, страница, таймаут
/// контейнера — работает по-настоящему; меняется только источник данных о блоке. Кэш резолвера для
/// подменённого id не используется, чтобы переключение сценария применялось сразу.
///
/// Спрятана за `@_spi(Internal)`: в обычном API её нет, но и не вырезана из релизных сборок — QA
/// проверяет то, что уходит клиентам. Каждая установка пишется в лог, чтобы включённую подмену было
/// невозможно не заметить.
final class EmbeddedBlockContentOverrides: EmbeddedBlockContentOverriding {

    static let shared = EmbeddedBlockContentOverrides()

    /// Подмену ставят из QA-кода приложения, а читает её резолвер на главном потоке — потоки могут
    /// не совпасть.
    private let lock = NSLock()

    private var overrides: [String: EmbeddedBlockResolution] = [:]

    func set(_ resolution: EmbeddedBlockResolution, for id: String) {
        lock.lock()
        overrides[id] = resolution
        lock.unlock()

        Logger.common(message: "[EmbeddedBlock] Debug override is ON for block id '\(id)': \(describe(resolution))",
                      level: .default,
                      category: .embeddedBlocks)
    }

    func remove(for id: String) {
        lock.lock()
        let removed = overrides.removeValue(forKey: id) != nil
        lock.unlock()

        guard removed else { return }
        Logger.common(message: "[EmbeddedBlock] Debug override is OFF for block id '\(id)'", category: .embeddedBlocks)
    }

    func removeAll() {
        lock.lock()
        let hadAny = !overrides.isEmpty
        overrides = [:]
        lock.unlock()

        guard hadAny else { return }
        Logger.common(message: "[EmbeddedBlock] All debug overrides are OFF", category: .embeddedBlocks)
    }

    func resolution(for id: String) -> EmbeddedBlockResolution? {
        lock.lock()
        defer { lock.unlock() }
        return overrides[id]
    }

    private func describe(_ resolution: EmbeddedBlockResolution) -> String {
        switch resolution {
        case .empty:
            return "empty"
        case .content(let content):
            switch content.source {
            case .url(let url): return url.absoluteString
            case .html: return "inline html"
            }
        }
    }
}
