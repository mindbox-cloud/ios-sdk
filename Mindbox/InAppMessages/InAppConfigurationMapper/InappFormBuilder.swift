//
//  InappFormBuilder.swift
//  Mindbox
//
//  Created by Sergei Semko on 25.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// Turns a chosen in-app into what the presentation draws: its variant with the images downloaded.
struct InappFormBuilder {

    private let dataFacade: InAppConfigurationDataFacadeProtocol

    init(dataFacade: InAppConfigurationDataFacadeProtocol) {
        self.dataFacade = dataFacade
    }

    /// Blocking by design — callers walk a list and stop at the first buildable in-app. Must not run
    /// on the selection queue: a download wait there would stall every targeting question behind it.
    func makeFormData(_ inapp: InAppTransitionData,
                      extraParams: [String: JSONValue]?,
                      operation: (name: String, body: String)?) -> InAppFormData? {
        Logger.common(message: "[InappFormBuilder] Starting in-app processing. [ID]: \(inapp.inAppId)", level: .debug, category: .inAppMessages)

        if case .modal(let modal) = inapp.content,
           modal.content.background.layers.contains(where: { $0.layerType == .webview }) {
            return InAppFormData(inAppId: inapp.inAppId,
                                 isPriority: inapp.isPriority,
                                 delayTime: inapp.delayTime,
                                 imagesDict: [:],
                                 firstImageValue: "",
                                 content: inapp.content,
                                 frequency: inapp.frequency,
                                 tags: inapp.tags,
                                 operation: operation,
                                 extraParams: extraParams)
        }

        let urlExtractorService = DI.injectOrFail(VariantImageUrlExtractorServiceProtocol.self)
        let imageValues = urlExtractorService.extractImageURL(from: inapp.content)

        let group = DispatchGroup()
        let imageDictQueue = DispatchQueue(label: "com.mindbox.imagedict.queue", attributes: .concurrent)
        var imageDict: [String: UIImage] = [:]
        var gotError = false

        for imageValue in imageValues {
            group.enter()
            Logger.common(message: "[InappFormBuilder] Initiating the process of image loading from the URL: \(imageValue)", level: .debug, category: .inAppMessages)
            dataFacade.downloadImage(withUrl: imageValue, inappId: inapp.inAppId, tags: inapp.tags) { result in
                defer {
                    group.leave()
                }

                switch result {
                case .success(let image):
                    imageDictQueue.async(flags: .barrier) {
                        imageDict[imageValue] = image
                    }
                case .failure:
                    gotError = true
                }
            }
        }

        group.wait()

        return imageDictQueue.sync {
            guard !imageDict.isEmpty, !gotError else { return nil }

            return InAppFormData(inAppId: inapp.inAppId,
                                 isPriority: inapp.isPriority,
                                 delayTime: inapp.delayTime,
                                 imagesDict: imageDict,
                                 firstImageValue: imageValues.first ?? "",
                                 content: inapp.content,
                                 frequency: inapp.frequency,
                                 tags: inapp.tags,
                                 operation: operation,
                                 extraParams: extraParams)
        }
    }
}
