//
//  EmbeddedBlockReadinessOverrides.swift
//  Mindbox
//
//  Created by vailence on 07.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Отладочная подмена условия готовности блока.
protocol EmbeddedBlockReadinessOverriding: AnyObject {

    /// `true` — блок становится готовым по факту загруженного документа, не дожидаясь `ready` от
    /// страницы.
    var treatsLoadedPageAsReady: Bool { get }
}

/// Временный костыль для страниц, которые ещё не умеют веб-контракт.
///
/// Обычное правило блока — готовность объявляет только сама страница: загруженный документ ничего
/// не говорит о том, есть ли блоку что показать, поэтому молчащую страницу добивает таймаут
/// контейнера. Пока контракт не реализован на вебе, проверить вёрстку блока этим правилом
/// невозможно: любая страница сворачивается в ноль через таймаут.
///
/// Подмена снимает ровно это ограничение и ничего больше: загрузился документ — показываем. Она
/// выключена по умолчанию и включается только явно из кода приложения, потому что со включённой
/// подменой сломанная страница выглядит как рабочая — а это ровно то, от чего защищает обычное
/// правило.
///
/// Уедет вместе с первой страницей, которая научится присылать `ready`.
final class EmbeddedBlockReadinessOverrides: EmbeddedBlockReadinessOverriding {

    static let shared = EmbeddedBlockReadinessOverrides()

    /// Флаг ставят из кода приложения, а читает его провайдер на главном потоке — потоки могут не
    /// совпасть.
    private let lock = NSLock()

    private var isLoadedPageTreatedAsReady = false

    var treatsLoadedPageAsReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isLoadedPageTreatedAsReady
    }

    func setTreatsLoadedPageAsReady(_ isEnabled: Bool) {
        lock.lock()
        let didChange = isLoadedPageTreatedAsReady != isEnabled
        isLoadedPageTreatedAsReady = isEnabled
        lock.unlock()

        guard didChange else { return }

        Logger.common(message: "[EmbeddedBlock] Debug readiness is \(isEnabled ? "ON" : "OFF"): a loaded page \(isEnabled ? "is" : "is no longer") treated as ready without the page contract",
                      level: .default,
                      category: .embeddedBlocks)
    }
}
