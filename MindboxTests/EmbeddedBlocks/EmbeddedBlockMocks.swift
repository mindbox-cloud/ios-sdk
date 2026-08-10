//
//  EmbeddedBlockMocks.swift
//  MindboxTests
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

extension EmbeddedBlockWebContent {

    static let stub = EmbeddedBlockWebContent(url: URL(string: "https://mindbox.ru/block.html")!)
}

/// Открыватель ссылок, который ничего не открывает: тесты смотрят, что до системы дошло, а что нет.
final class EmbeddedBlockURLOpenerMock: EmbeddedBlockURLOpening {

    /// Что отвечать на вопрос «система это откроет?». `canOpenURL` пропускает системные схемы, и
    /// тесты политики схем должны проверять именно политику, а не этот ответ.
    var canOpenAnything = true

    private(set) var openedURLs: [URL] = []

    func canOpen(_ url: URL) -> Bool {
        canOpenAnything
    }

    func open(_ url: URL) {
        openedURLs.append(url)
    }
}
