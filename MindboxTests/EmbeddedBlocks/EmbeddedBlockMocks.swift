//
//  EmbeddedBlockMocks.swift
//  MindboxTests
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
@testable import Mindbox

extension EmbeddedBlockWebContent {

    static let stub = EmbeddedBlockWebContent(url: URL(string: "https://mindbox.ru/block.html")!)

    static let other = EmbeddedBlockWebContent(url: URL(string: "https://mindbox.ru/another-block.html")!)
}
