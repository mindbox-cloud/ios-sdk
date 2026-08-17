//
//  MotionActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Device motion gestures — shake and flip — for the page.
///
/// The only handler that also speaks unprompted: a gesture arrives from the sensors with no
/// request in hand, so the page it belongs to is remembered from the request that started
/// monitoring. Weakly — a gesture must not be what keeps a finished show alive.
final class MotionActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.motionStart, .motionStop]

    private weak var host: WebBridgeHost?

    /// Whether the sensors were ever asked for. Teardown must not start a service just to stop
    /// it, and every show ends whether or not it ever used motion.
    private var isServiceInUse = false

    private lazy var service: MotionServiceProtocol = {
        isServiceInUse = true
        let service = makeService()
        service.onGestureDetected = { [weak self] gesture, data in
            self?.report(gesture: gesture, data: data)
        }
        return service
    }()

    private let makeService: () -> MotionServiceProtocol

    init(makeService: @escaping () -> MotionServiceProtocol
         = { DI.injectOrFail(MotionServiceProtocol.self) }) {
        self.makeService = makeService
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        self.host = host

        switch message.parsedAction {
        case .motionStart:
            start(message, host: host)
        case .motionStop:
            service.stopMonitoring()
            host.respondSuccess(to: message)
        default:
            // Unreachable: the registry routes only what `actions` claims.
            break
        }
    }

    /// A shake is detected by the system and arrives at the view, not at the bridge.
    func handleSystemShake() {
        guard isServiceInUse else { return }

        service.handleSystemShake()
    }

    func tearDown() {
        guard isServiceInUse else { return }

        service.stopMonitoring()
    }
}

private extension MotionActionHandler {

    func start(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let payload = message.payloadObject else {
            host.respondError("Invalid payload: missing 'gestures' array", to: message)
            return
        }

        guard case .array(let requested) = payload["gestures"] else {
            host.respondError("Invalid payload: 'gestures' must be an array", to: message)
            return
        }

        var gestures = Set<MotionGesture>()
        for item in requested {
            if case .string(let name) = item, let gesture = MotionGesture(rawValue: name) {
                gestures.insert(gesture)
            }
        }

        guard !gestures.isEmpty else {
            host.respondError("No valid gestures provided. Available: shake, flip", to: message)
            return
        }

        let result = service.startMonitoring(gestures: gestures)

        guard !result.allUnavailable else {
            host.respondError(
                "No sensors available for requested gestures: \(result.unavailable.map(\.rawValue).joined(separator: ", "))",
                to: message
            )
            return
        }

        // A partial start is still a start: the page is told which gestures it will not get
        // rather than being refused everything it asked for.
        var payloadBack: [String: JSONValue] = ["success": .bool(true)]
        if !result.unavailable.isEmpty {
            payloadBack["unavailable"] = .array(result.unavailable.map { .string($0.rawValue) })
        }

        host.respond(to: message, payload: .object(payloadBack))
    }

    /// Pushed as a request, not a response: nothing asked for this gesture, it just happened.
    func report(gesture: MotionGesture, data: [String: Any]) {
        guard let host else { return }

        var payload: [String: JSONValue] = ["gesture": .string(gesture.rawValue)]
        for (key, value) in data {
            if let jsonValue = JSONValue(any: value) {
                payload[key] = jsonValue
            }
        }

        host.send(BridgeMessage(type: .request,
                                action: BridgeMessage.Action.motionEvent.rawValue,
                                payload: .object(payload)))
    }
}
