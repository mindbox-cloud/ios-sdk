//
//  InAppPresentationManagerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 07.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("In-app presentation manager", .tags(.inAppSchedule))
@MainActor
struct InAppPresentationManagerTests {

    private final class DisplayUseCaseSpy: PresentationDisplayUseCaseProtocol {
        private(set) var presentCount = 0
        private(set) var dismissCount = 0

        var receivedOnClose: (() -> Void)?

        func presentInAppUIModel(model: InAppFormData,
                                 onPresented: @escaping () -> Void,
                                 onTapAction: @escaping InAppMessageTapAction,
                                 onClose: @escaping () -> Void,
                                 onError: @escaping (InAppPresentationError) -> Void) {
            presentCount += 1
            receivedOnClose = onClose
        }

        func dismissInAppUIModel(onClose: @escaping () -> Void) {
            dismissCount += 1
            onClose()
        }

        func onPresented(id: String, _ completion: @escaping () -> Void) {
            completion()
        }
    }

    @Test("A discard closes the show through its own completion and names itself a discard")
    func discardCompletesTheShow() async {
        let display = DisplayUseCaseSpy()
        let manager = InAppPresentationManager(displayUseCase: display)
        var completions: [Bool] = []

        manager.present(inAppFormData: Self.formData(id: "discarded"),
                        onPresented: {},
                        onTapAction: { _, _ in },
                        onPresentationCompleted: { completions.append($0) },
                        onError: { _ in })
        await awaitMainQueue()
        #expect(display.presentCount == 1)

        NotificationCenter.default.post(name: .shouldDiscardInapps, object: nil)
        await awaitMainQueue(turns: 3)

        #expect(display.dismissCount == 1)
        #expect(completions == [true])
        withExtendedLifetime(manager) {}
    }

    @Test("A close from the page completes the show as a close, not a discard")
    func pageCloseCompletesTheShowAsAClose() async {
        let display = DisplayUseCaseSpy()
        let manager = InAppPresentationManager(displayUseCase: display)
        var completions: [Bool] = []

        manager.present(inAppFormData: Self.formData(id: "closed"),
                        onPresented: {},
                        onTapAction: { _, _ in },
                        onPresentationCompleted: { completions.append($0) },
                        onError: { _ in })
        await awaitMainQueue()

        display.receivedOnClose?()
        await awaitMainQueue(turns: 2)

        #expect(completions == [false])
        withExtendedLifetime(manager) {}
    }

    private func awaitMainQueue(turns: Int = 1) async {
        for _ in 0..<turns {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    private static func formData(id: String) -> InAppFormData {
        let modal = ModalFormVariant(content: InappFormVariantContent(background: ContentBackground(layers: []), elements: nil))
        return InAppFormData(inAppId: id,
                             isPriority: false,
                             delayTime: nil,
                             imagesDict: [:],
                             firstImageValue: "",
                             content: .modal(modal),
                             frequency: .unlimited)
    }
}
