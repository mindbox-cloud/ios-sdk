//
//  HapticActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

final class HapticActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.haptic]

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

    func prepare() {
        service.prepare()
    }

    func tearDown() {
        guard isEngineInUse else { return }

        service.stopPattern()
    }
}
