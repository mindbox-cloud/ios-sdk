//
//  OperationActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Mindbox operations the page asks the SDK to send.
///
/// Two shapes of the same thing: `asyncOperation` is queued and confirmed straight away, while
/// `syncOperation` waits for the backend and hands the raw body back — the page's own tracker
/// reads a `status` out of it that the SDK has no business interpreting.
final class OperationActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.asyncOperation, .syncOperation]

    private lazy var featureToggleManager: FeatureToggleManager = makeFeatureToggleManager()
    private lazy var databaseRepository: DatabaseRepositoryProtocol = makeDatabaseRepository()
    private lazy var eventRepository: EventRepository = makeEventRepository()

    private let makeFeatureToggleManager: () -> FeatureToggleManager
    private let makeDatabaseRepository: () -> DatabaseRepositoryProtocol
    private let makeEventRepository: () -> EventRepository

    init(featureToggleManager: @escaping @autoclosure () -> FeatureToggleManager
         = DI.injectOrFail(FeatureToggleManager.self),
         databaseRepository: @escaping @autoclosure () -> DatabaseRepositoryProtocol
         = DI.injectOrFail(DatabaseRepositoryProtocol.self),
         eventRepository: @escaping @autoclosure () -> EventRepository
         = DI.injectOrFail(EventRepository.self)) {
        self.makeFeatureToggleManager = featureToggleManager
        self.makeDatabaseRepository = databaseRepository
        self.makeEventRepository = eventRepository
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let operation = operation(from: message, host: host) else {
            host.respondError("Invalid payload: could not parse operation/body or encode the operation body",
                              to: message)
            return
        }

        switch message.parsedAction {
        case .asyncOperation:
            queue(operation, message: message, host: host)
        case .syncOperation:
            send(operation, message: message, host: host)
        default:
            // Unreachable: the registry routes only what `actions` claims.
            break
        }
    }
}

// MARK: - Actions

private extension OperationActionHandler {

    func queue(_ operation: (name: String, body: String), message: BridgeMessage, host: WebBridgeHost) {
        let customEvent = CustomEvent(name: operation.name, payload: operation.body)
        let event = Event(type: .customEvent, body: BodyEncoder(encodable: customEvent).body)

        do {
            try databaseRepository.create(event: event)
            Logger.common(message: "[WebView] asyncOperation '\(operation.name)' queued",
                          level: .info,
                          category: host.logCategory)
        } catch {
            Logger.common(message: "[WebView] asyncOperation '\(operation.name)' failed: \(error)",
                          level: .error,
                          category: host.logCategory)
            host.respondError("Failed to queue operation: \(error.localizedDescription)", to: message)
            return
        }

        host.respondSuccess(to: message)
    }

    func send(_ operation: (name: String, body: String), message: BridgeMessage, host: WebBridgeHost) {
        let customEvent = CustomEvent(name: operation.name, payload: operation.body)
        let event = Event(type: .syncEvent, body: BodyEncoder(encodable: customEvent).body)

        Logger.common(message: "[WebView] syncOperation '\(operation.name)' sending",
                      level: .info,
                      category: host.logCategory)

        // HTTP 2xx → forward the raw body to JS as a Response so the JS Tracker
        // can dispatch onSuccess / onValidationError by the body's `status`.
        // 4xx, 5xx and network failures stay on the MindboxError → Error path.
        eventRepository.sendRaw(event: event) { [weak host] result in
            DispatchQueue.main.async {
                guard let host else { return }

                let outgoing = OperationActionHandler.makeSyncOperationResponse(
                    result: result,
                    action: message.action,
                    id: message.id
                )

                switch outgoing.type {
                case .response:
                    Logger.common(message: "[WebView] syncOperation '\(operation.name)' success",
                                  level: .info,
                                  category: host.logCategory)
                case .error:
                    if case .failure(let error) = result {
                        Logger.common(message: "[WebView] syncOperation '\(operation.name)' failed: \(error)",
                                      level: .error,
                                      category: host.logCategory)
                    } else {
                        Logger.common(message: "[WebView] syncOperation '\(operation.name)' failed: non-UTF-8 response body",
                                      level: .error,
                                      category: host.logCategory)
                    }
                default:
                    break
                }

                host.send(outgoing)
            }
        }
    }

    /// The operation name and its body, with the in-app tags merged in and encoded ready to send.
    func operation(from message: BridgeMessage, host: WebBridgeHost) -> (name: String, body: String)? {
        guard let payload = message.payloadObject,
              case .string(let name)? = payload["operation"],
              !name.isEmpty,
              let body = payload["body"] else {
            return nil
        }

        let gatedTags = featureToggleManager.gatedTags(host.tags)
        let mergedBody = JSONValue.mergingInAppTags(gatedTags, into: body)

        guard let data = try? JSONEncoder().encode(mergedBody),
              let bodyString = String(data: data, encoding: .utf8) else {
            return nil
        }

        return (name, bodyString)
    }
}

// MARK: - Response mapping

extension OperationActionHandler {

    /// Maps the raw `sendRaw` result of a `syncOperation` request to the outgoing
    /// `BridgeMessage` sent back to JS. Pure function — no side effects — extracted
    /// to keep the JS-bridge contract independently unit-testable.
    static func makeSyncOperationResponse(
        result: Result<Data, MindboxError>,
        action: String,
        id: UUID
    ) -> BridgeMessage {
        switch result {
        case .success(let data):
            guard let bodyString = String(data: data, encoding: .utf8) else {
                return BridgeMessage(
                    type: .error,
                    action: action,
                    payload: .object(["error": .string("Response body is not valid UTF-8")]),
                    id: id
                )
            }
            return BridgeMessage(
                type: .response,
                action: action,
                payload: .string(bodyString),
                id: id
            )
        case .failure(let error):
            return BridgeMessage(
                type: .error,
                action: action,
                payload: .string(error.createDataJSON()),
                id: id
            )
        }
    }
}
