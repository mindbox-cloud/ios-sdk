//
//  InAppMessagesEventSender.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 05.04.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

class InappMessageEventSender {
    private let inAppMessagesManager: InAppCoreManagerProtocol?

    init(inAppMessagesManager: InAppCoreManagerProtocol?) {
        self.inAppMessagesManager = inAppMessagesManager
    }

    func sendEventIfEnabled(_ operatingSystemName: String, jsonString: String?) {
        let lowercasedName = operatingSystemName.lowercased()
        let jsonString = jsonString ?? ""

        let model = decodeInAppOperationJSONModel(from: jsonString)
        let event: InAppMessageTriggerEvent = .applicationEvent(ApplicationEvent(name: lowercasedName, model: model))
        inAppMessagesManager?.sendEvent(event)
    }

    private func decodeInAppOperationJSONModel(from jsonString: String) -> InappOperationJSONModel? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            let model = try JSONDecoder().decode(InappOperationJSONModel.self, from: jsonData)
            return model
        } catch {
            Logger.common(message: "Failed to decode InappOperationJSONModel: \(error.localizedDescription)", level: .error, category: .inAppMessages)
            return nil
        }
    }
}
