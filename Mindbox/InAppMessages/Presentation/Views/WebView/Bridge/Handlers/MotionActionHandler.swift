//
//  MotionActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

final class MotionActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.motionStart, .motionStop]

    private weak var host: WebBridgeHost?

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
            break
        }
    }

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
            host.respondError(.invalidPayload, detail: "missing 'gestures' array", to: message)
            return
        }

        guard case .array(let requested) = payload["gestures"] else {
            host.respondError(.invalidPayload, detail: "'gestures' must be an array", to: message)
            return
        }

        var gestures = Set<MotionGesture>()
        for item in requested {
            if case .string(let name) = item, let gesture = MotionGesture(rawValue: name) {
                gestures.insert(gesture)
            }
        }

        guard !gestures.isEmpty else {
            if Self.areAllNonEmptyStrings(requested) {
                host.respondError(.unsupportedValue, detail: "no known gesture requested, available: shake, flip", to: message)
            } else {
                host.respondError(.invalidPayload, detail: "'gestures' must be a non-empty list of gesture names", to: message)
            }
            return
        }

        let result = service.startMonitoring(gestures: gestures)

        guard !result.allUnavailable else {
            host.respondError(.gesturesUnavailable,
                              detail: "no sensors for \(result.unavailable.map(\.rawValue).joined(separator: ", "))",
                              to: message)
            return
        }

        var payloadBack: [String: JSONValue] = ["success": .bool(true)]
        if !result.unavailable.isEmpty {
            payloadBack["unavailable"] = .array(result.unavailable.map { .string($0.rawValue) })
        }

        host.respond(to: message, payload: .object(payloadBack))
    }

    static func areAllNonEmptyStrings(_ values: [JSONValue]) -> Bool {
        !values.isEmpty && values.allSatisfy { value in
            guard case .string(let name) = value else { return false }
            return !name.isEmpty
        }
    }

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
