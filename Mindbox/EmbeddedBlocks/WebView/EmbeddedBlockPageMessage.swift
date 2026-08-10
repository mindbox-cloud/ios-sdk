//
//  EmbeddedBlockPageMessage.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import CoreGraphics
import Foundation

/// Что страница встроенного блока сообщает нативной стороне.
///
/// Ядро разбирает только core-слой — `ready`, `heightChanged` и `empty`, они нужны любому блоку. Всё
/// остальное с валидным конвертом уходит в механику как `action`: ядро не знает и не должно
/// знать словарь конкретной механики.
///
/// Формат пока свой и минимальный: страница шлёт `{"type": ..., ...}`. Сведение с общим
/// JS-мостом инаппов (`MindboxWebBridge`) — отдельная задача, до неё этот разбор трогать не нужно.
enum EmbeddedBlockPageMessage: Equatable {

    /// Страница отрисовалась и просит контейнер стать `height` точек высотой.
    case ready(height: CGFloat)

    /// Страница перемерилась уже после показа — например, подгрузился контент.
    case heightChanged(height: CGFloat)

    /// Странице нечего показать — например, блок выключен в админке. Это не ошибка.
    case empty

    /// Действие сверх core-слоя — его смысл знает механика блока.
    case action(EmbeddedBlockPageAction)

    /// Тело сообщения приходит из WebKit как `Any`. Строку разбираем как JSON, словарь берём как
    /// есть: страница может присылать и то и другое, а падать на форме сообщения тут незачем.
    init?(body: Any) {
        let payload: [String: Any]

        if let dictionary = body as? [String: Any] {
            payload = dictionary
        } else if let json = body as? String,
                  let data = json.data(using: .utf8),
                  let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload = decoded
        } else {
            return nil
        }

        guard let type = payload["type"] as? String else {
            return nil
        }

        switch type {
        case "ready":
            guard let height = EmbeddedBlockPageMessage.height(from: payload) else { return nil }
            self = .ready(height: height)
        case "heightChanged":
            guard let height = EmbeddedBlockPageMessage.height(from: payload) else { return nil }
            self = .heightChanged(height: height)
        case "empty":
            self = .empty
        default:
            self = .action(EmbeddedBlockPageAction(type: type, payload: payload))
        }
    }

    /// JS отдаёт число как `Double`, но целые значения могут прийти и как `Int` — берём оба.
    private static func height(from payload: [String: Any]) -> CGFloat? {
        if let height = payload["height"] as? Double {
            return CGFloat(height)
        }

        if let height = payload["height"] as? Int {
            return CGFloat(height)
        }

        return nil
    }
}

/// Конверт действия, которое ядро не разбирает, а передаёт механике: тип и весь payload
/// сообщения как есть.
struct EmbeddedBlockPageAction: Equatable {

    let type: String
    let payload: [String: Any]

    static func == (lhs: EmbeddedBlockPageAction, rhs: EmbeddedBlockPageAction) -> Bool {
        lhs.type == rhs.type && (lhs.payload as NSDictionary).isEqual(to: rhs.payload)
    }
}
