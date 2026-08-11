//
//  EmbeddedBlockWebContent.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

struct EmbeddedBlockWebContent: Equatable {

    enum Source: Equatable {
        case url(URL)

        /// Разметка вместо адреса. Нужна отладочной подмене контента: сценарии приёмки — пустая
        /// страница, молчащая страница, ответ уже после таймаута — в сеть не выкладываются.
        case html(String)
    }

    let source: Source

    init(url: URL) {
        source = .url(url)
    }

    init(html: String) {
        source = .html(html)
    }
}
