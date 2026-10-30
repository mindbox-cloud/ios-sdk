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

    var isStartPending: Bool { deferred.isStartAwaitingSessionCheck }

    var holdsAnAttempt: Bool { (isStarted || isPaused) && (isAttemptAlive || deferred.parksContent) }

    func contentIsKept() { if isAwaitingAnswer { onKeptContentChanged?() } }

    func keptContentIsReleased() { onKeptContentChanged?() }
}
