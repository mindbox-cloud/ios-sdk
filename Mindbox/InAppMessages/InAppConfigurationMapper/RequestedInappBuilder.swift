//
//  RequestedInappBuilder.swift
//  Mindbox
//
//  Created by Sergei Semko on 16.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class RequestedInappBuilder {

    private let inappFilterService: InappFilterProtocol
    private let formBuilder: InappFormBuilder
    private let queue = DispatchQueue(label: "com.Mindbox.requestedInappBuilder.queue")

    init(inappFilterService: InappFilterProtocol, dataFacade: InAppConfigurationDataFacadeProtocol) {
        self.inappFilterService = inappFilterService
        self.formBuilder = InappFormBuilder(dataFacade: dataFacade, imageFailures: .atOnce)
    }

    func build(_ id: String,
               params: [String: JSONValue],
               from candidates: ConfigCandidates,
               _ completion: @escaping (InAppFormData?) -> Void) {
        queue.async {
            let formData = self.overlayTransition(forId: id, in: candidates).flatMap {
                self.formBuilder.makeFormData($0, extraParams: params, operation: nil)
            }

            DispatchQueue.main.async {
                completion(formData)
            }
        }
    }

    private func overlayTransition(forId id: String, in candidates: ConfigCandidates) -> InAppTransitionData? {
        guard let inapp = inappFilterService.filter(id: id, in: candidates) else { return nil }

        guard let variant = inapp.form.variants.first(where: { $0.isOverlayPresentable }) else {
            let reason = inapp.form.variants.isEmpty
                ? "has no variant left to render"
                : "is drawn inside the host layout and cannot be shown over the screen"
            Logger.common(message: "[RequestedInappBuilder] In-app \(id) \(reason).", level: .error, category: .inAppMessages)
            return nil
        }

        return InAppTransitionData(inAppId: inapp.id,
                                   isPriority: inapp.isPriority,
                                   delayTime: inapp.delayTime,
                                   content: variant,
                                   frequency: inapp.frequency,
                                   tags: inapp.tags)
    }
}
