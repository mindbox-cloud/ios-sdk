//
//  HapticActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Haptic feedback for the page.
///
/// Owns the engine outright. It has to: the service is registered `.transient`, so anyone else
/// resolving it would get a second engine — and preparing one while playing on another silently
/// does nothing.
final class HapticActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.haptic]

    /// Whether the engine was ever asked for. Teardown must not build one just to stop it: most
    /// shows never touch haptics, and every one of them ends.
    private var isEngineInUse = false

    private lazy var service: HapticServiceProtocol = {
        isEngineInUse = true
        return makeService()
    }()

    private let makeService: () -> HapticServiceProtocol

    init(makeService: @escaping () -> HapticServiceProtocol
         = { DI.injectOrFail(HapticServiceProtocol.self) }) {
        self.makeService = makeService
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        service.handle(message: message)
        host.respondSuccess(to: message)
    }

    /// Warms the engine up so the first tap does not pay for starting it.
    ///
    /// Called when the page reports it is up, which is a lifecycle event rather than an action —
    /// hence the door in from outside a request.
    func prepare() {
        service.prepare()
    }

    func tearDown() {
        guard isEngineInUse else { return }

        service.stopPattern()
    }
}
