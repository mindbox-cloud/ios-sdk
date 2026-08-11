//
//  EmbeddedBlockResolver.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Во что разрешается id встроенного блока.
enum EmbeddedBlockResolution: Equatable {

    /// За id закреплён контент — блок грузит его.
    case content(EmbeddedBlockWebContent)

    /// За id ничего нет — блок выключен в админке или id неизвестен. Не ошибка.
    case empty
}

/// Отвечает на единственный вопрос: что показывает блок с данным id.
///
/// Резолвер — общая точка всех контейнеров: несколько блоков с одним id разрешаются одними
/// данными, при этом вью, страница и состояние у каждого блока остаются своими.
protocol EmbeddedBlockResolving: AnyObject {

    /// - Parameter forceRefresh: `true` — не брать кэш, спросить данные заново. Нужно перезагрузке
    ///   блока: переехавший или выключенный блок иначе вечно доставал бы из кэша прежний адрес.
    func resolve(_ id: String, forceRefresh: Bool, completion: @escaping (EmbeddedBlockResolution) -> Void)
}

extension EmbeddedBlockResolving {

    func resolve(_ id: String, completion: @escaping (EmbeddedBlockResolution) -> Void) {
        resolve(id, forceRefresh: false, completion: completion)
    }
}

/// Откуда резолвер узнаёт, что стоит за id блока.
///
/// Сейчас это заглушка со статической страницей. Когда появится конфиг из админки, здесь окажется
/// настоящая загрузка, а кэш и очередь ожидающих в резолвере не изменятся.

typealias EmbeddedBlockContentLoading = (String, @escaping (EmbeddedBlockResolution) -> Void) -> Void

final class EmbeddedBlockResolver: EmbeddedBlockResolving {

    /// Страница ленты сторизов на статике. Временно захардкожена: когда появится конфиг из
    /// админки, адрес приедет оттуда вместе с маппингом id → контент.
    private static let storiesPageURL = "https://mobile-static.mindbox.ru/beta/inapps/webview/content/stories.html"

    private let load: EmbeddedBlockContentLoading
    private let overrides: EmbeddedBlockContentOverriding

    /// Кэш на id: ответ, полученный один раз, достаётся всем следующим блокам сразу.
    private var cache: [String: EmbeddedBlockResolution] = [:]

    /// Кто уже ждёт ответ по этому id. «Одна загрузка данных на id» — это про то, что второй блок
    /// с тем же id встаёт в эту очередь, а не идёт за данными сам.
    private var waiting: [String: [(EmbeddedBlockResolution) -> Void]] = [:]

    init(load: @escaping EmbeddedBlockContentLoading = EmbeddedBlockResolver.loadStubbedStoriesPage,
         overrides: EmbeddedBlockContentOverriding = EmbeddedBlockContentOverrides.shared) {
        self.load = load
        self.overrides = overrides
    }

    func resolve(_ id: String, forceRefresh: Bool, completion: @escaping (EmbeddedBlockResolution) -> Void) {
        guard Thread.isMainThread else {
            Logger.common(message: "[EmbeddedBlock] Resolver was asked about id '\(id)' off the main thread, continuing on it",
                          level: .error,
                          category: .embeddedBlocks)
            DispatchQueue.main.async { [weak self] in
                self?.resolve(id, forceRefresh: forceRefresh, completion: completion)
            }
            return
        }

        // Отладочная подмена сильнее и данных, и кэша: приёмка переключает сценарий на ходу, и
        // закэшированный ответ мешал бы этому.
        if let overridden = overrides.resolution(for: id) {
            completion(overridden)
            return
        }

        if !forceRefresh, let cached = cache[id] {
            completion(cached)
            return
        }

        // Загрузка по этому id уже идёт. Присоединиться к ней правильно и для `forceRefresh`:
        // ответ, который она вот-вот принесёт, свежий по определению.
        if waiting[id] != nil {
            waiting[id]?.append(completion)
            return
        }

        waiting[id] = [completion]

        load(id) { [weak self] resolution in
            EmbeddedBlockResolver.onMain {
                guard let self else { return }

                self.cache[id] = resolution
                let completions = self.waiting.removeValue(forKey: id) ?? []
                completions.forEach { $0(resolution) }
            }
        }
    }

    private static func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// Конфига ещё нет, поэтому любой id разрешается в страницу ленты сторизов. Это единственное
    /// место, которое заменит настоящий конфиг из админки: id → контент блока, выключенный или
    /// неизвестный блок → `.empty`.
    static func loadStubbedStoriesPage(_ id: String, completion: @escaping (EmbeddedBlockResolution) -> Void) {
        guard let url = URL(string: storiesPageURL) else {
            Logger.common(message: "[EmbeddedBlock] Invalid stories page URL, resolving id '\(id)' as empty",
                          category: .embeddedBlocks)
            completion(.empty)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Resolved block id '\(id)' to \(url.absoluteString)", category: .embeddedBlocks)
        completion(.content(EmbeddedBlockWebContent(url: url)))
    }
}
