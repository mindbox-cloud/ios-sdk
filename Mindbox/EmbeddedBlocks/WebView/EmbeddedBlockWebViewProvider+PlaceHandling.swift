//
//  EmbeddedBlockWebViewProvider+PlaceHandling.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

// MARK: - The registry's view of the block

extension EmbeddedBlockWebViewProvider: EmbeddedBlockPlaceHandling {

    var isActive: Bool { isStarted }

    var holdsAnAttempt: Bool { (isStarted || isPaused) && (isAttemptAlive || pendingResolution?.resolution.content != nil) }
}
