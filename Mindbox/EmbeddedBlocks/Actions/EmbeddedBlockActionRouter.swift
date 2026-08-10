//
//  EmbeddedBlockActionRouter.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// Обработчик действий страницы сверх core-слоя.
protocol EmbeddedBlockActionHandling: AnyObject {

    func handle(_ action: EmbeddedBlockPageAction)
}

/// Кто на самом деле открывает ссылку.
///
/// Шов нужен и тестам, и на будущее: открытие ссылок в SDK уже живёт в `MindboxURLHandlerDelegate`,
/// и когда блоки поедут на общий мост инаппов, здесь окажется он, а не `UIApplication` напрямую.
protocol EmbeddedBlockURLOpening {

    func canOpen(_ url: URL) -> Bool

    func open(_ url: URL)
}

final class EmbeddedBlockSystemURLOpener: EmbeddedBlockURLOpening {

    func canOpen(_ url: URL) -> Bool {
        UIApplication.shared.canOpenURL(url)
    }

    func open(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

/// Универсальный словарь действий страницы — один на все механики.
///
/// Блок не знает, какая механика внутри, поэтому и действия у страниц общие: любая страница,
/// говорящая этим словарём, получает нативное поведение без нового кода в SDK. Незнакомое
/// действие — не ошибка: словарь у веб-стороны может быть новее, чем у SDK, тогда действие
/// просто логируется.
///
/// [WIP]
final class EmbeddedBlockActionRouter: EmbeddedBlockActionHandling {

    private enum ActionType {
        static let openUrl = "openUrl"
    }

    /// Веб-адрес — это переход по контенту, и его странице позволено открывать всегда.
    private enum WebScheme {
        static let all: Set<String> = ["http", "https"]
    }

    private let urlOpener: EmbeddedBlockURLOpening

    /// Схемы, которые хост объявил своими. Читаются один раз: Info.plist по ходу работы не меняется.
    private let hostAppSchemes: Set<String>

    init(urlOpener: EmbeddedBlockURLOpening = EmbeddedBlockSystemURLOpener(),
         hostAppSchemes: Set<String> = EmbeddedBlockActionRouter.hostAppSchemes(in: Bundle.main.infoDictionary)) {
        self.urlOpener = urlOpener
        self.hostAppSchemes = hostAppSchemes
    }

    func handle(_ action: EmbeddedBlockPageAction) {
        switch action.type {
        case ActionType.openUrl:
            openUrl(from: action)
        default:
            Logger.common(message: "[EmbeddedBlock] Unknown page action: \(action.type)",
                          category: .embeddedBlocks)
        }
    }

    /// Схемы из `CFBundleURLTypes` — те, по которым система вернёт пользователя в это же приложение.
    ///
    /// На вход идёт сам `infoDictionary`, а не `Bundle`: подменить бандлу его Info.plist в тесте
    /// нельзя, а разбор проверить надо.
    static func hostAppSchemes(in infoDictionary: [String: Any]?) -> Set<String> {
        let types = infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let schemes = types
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }
            .map { $0.lowercased() }

        return Set(schemes)
    }

    private func openUrl(from action: EmbeddedBlockPageAction) {
        guard let raw = action.payload["url"] as? String,
              let url = URL(string: raw) else {
            Logger.common(message: "[EmbeddedBlock] openUrl with an invalid url: \(action.payload)",
                          category: .embeddedBlocks)
            return
        }

        guard isAllowed(url) else {
            Logger.common(message: """
            [EmbeddedBlock] openUrl refused for scheme '\(url.scheme ?? "none")': a block page may open \
            web addresses and this app's own deep links, but not system-level actions.
            """, category: .embeddedBlocks)
            return
        }

        guard urlOpener.canOpen(url) else {
            Logger.common(message: "[EmbeddedBlock] openUrl cannot be opened by the system: \(url.absoluteString)",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Opening url: \(url.absoluteString)", category: .embeddedBlocks)
        urlOpener.open(url)
    }

    /// Страница блока приезжает из сети, поэтому решать за пользователя, что откроет система, ей не
    /// положено: `tel:`, `sms:`, `itms-apps:` и схемы чужих приложений — это уже не переход по
    /// контенту, а действие от его имени, и `canOpenURL` для них проходит.
    ///
    /// Разрешено поэтому ровно то, что никуда пользователя не увозит: веб-адреса и диплинки в само
    /// это приложение. Понадобится большее — это отдельное явное согласие хоста, а не молчаливое
    /// право страницы.
    private func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }

        return WebScheme.all.contains(scheme) || hostAppSchemes.contains(scheme)
    }
}
