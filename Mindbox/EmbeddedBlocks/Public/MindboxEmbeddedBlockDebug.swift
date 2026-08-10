//
//  MindboxEmbeddedBlockDebug.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Отладочное управление содержимым встроенных блоков — для тестового приложения и приёмки.
///
/// Подменяет ответ на вопрос «что стоит за этим id», то есть встаёт ровно на место конфига из
/// админки. Всё, что ниже — резолвер, провайдер, страница, бюджет ожидания у контейнера — работает
/// без изменений, поэтому приёмка проверяет боевой путь, а не отдельный тестовый режим.
///
/// Не часть публичного API: доступно только через `@_spi(Internal) import Mindbox`. Из релизных
/// сборок не вырезано намеренно — QA проверяет ровно то, что уходит клиентам, — поэтому каждая
/// установка подмены пишется в лог.
@_spi(Internal)
public enum MindboxEmbeddedBlockDebug {

    /// Чем подменить содержимое блока.
    public enum Content {

        /// Адрес страницы. Так гоняются сценарии на реальной сети — включая заведомо недоступный
        /// адрес, чтобы получить провал загрузки.
        case url(URL)

        /// Готовая разметка. Так задаются сценарии, которых в сети нет: страница, сообщающая
        /// «пусто», молчащая страница, страница с ответом после таймаута.
        case html(String)

        /// За id ничего не закреплено: блок выключен в админке или id неизвестен.
        case empty
    }

    /// Подменяет содержимое блока с этим id. Действует на блоки, которые начнут загрузку после
    /// вызова: уже показанный блок надо перезагрузить или заново открыть экран.
    public static func setContent(_ content: Content, for id: String) {
        EmbeddedBlockContentOverrides.shared.set(content.resolution, for: id)
    }

    /// Возвращает блоку его обычное содержимое.
    public static func removeContent(for id: String) {
        EmbeddedBlockContentOverrides.shared.remove(for: id)
    }

    /// Снимает все подмены сразу.
    public static func removeAllContent() {
        EmbeddedBlockContentOverrides.shared.removeAll()
    }

    /// Показывать блок, как только загрузился документ, не дожидаясь `ready` от страницы.
    ///
    /// Нужно ровно одному сценарию: посмотреть, как блок выглядит и ведёт себя в вёрстке хоста,
    /// пока веб-контракт не реализован на странице. По обычному правилу такая страница молчит,
    /// а значит сворачивается по таймауту контейнера, и увидеть в блоке нечего.
    ///
    /// Выключено по умолчанию и ставится один раз при старте приложения. Держать включённым
    /// дольше проверки UI не стоит: со включённым флагом сломанная страница выглядит как рабочая.
    /// `ready` от страницы флаг не отменяет — он лишь добавляет второй повод показать блок,
    /// поэтому страница, которая контракт умеет, ведёт себя одинаково с ним и без него.
    public static var treatsLoadedPageAsReady: Bool {
        get { EmbeddedBlockReadinessOverrides.shared.treatsLoadedPageAsReady }
        set { EmbeddedBlockReadinessOverrides.shared.setTreatsLoadedPageAsReady(newValue) }
    }
}

@_spi(Internal)
extension MindboxEmbeddedBlockDebug.Content {

    var resolution: EmbeddedBlockResolution {
        switch self {
        case .url(let url):
            return .content(EmbeddedBlockWebContent(url: url))
        case .html(let html):
            return .content(EmbeddedBlockWebContent(html: html))
        case .empty:
            return .empty
        }
    }
}
