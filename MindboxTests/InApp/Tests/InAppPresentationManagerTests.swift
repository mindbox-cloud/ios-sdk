//
//  InAppPresentationManagerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 07.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
import UIKit
@testable import Mindbox

@Suite("In-app presentation manager", .tags(.inAppSchedule))
@MainActor
struct InAppPresentationManagerTests {

    @Test("A discard closes the show through its own completion and names itself a discard")
    func discardCompletesTheShow() async {
        let display = PresentationDisplaySpy()
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

    @Test("A discard heard on main closes the show before the post returns, ahead of anything queued behind it on main")
    func discardHeardOnMainClosesTheShowAtOnce() {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)

        present(on: manager, id: "on-screen")
        NotificationCenter.default.post(name: .shouldDiscardInapps, object: nil)

        #expect(display.dismissCount == 1)
        #expect(display.onScreen == nil)
        withExtendedLifetime(manager) {}
    }

    @Test("A close from the page completes the show as a close, not a discard")
    func pageCloseCompletesTheShowAsAClose() async {
        let display = PresentationDisplaySpy()
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

    @Test("Two shows started in one turn leave one window: the first completes as closed, the second stays on screen")
    func twoShowsInOneTurnLeaveOneWindow() async {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)
        var firstCompletions: [Bool] = []
        var secondCompletions: [Bool] = []

        present(on: manager, id: "first", onCompleted: { firstCompletions.append($0) })
        present(on: manager, id: "second", onCompleted: { secondCompletions.append($0) })
        await awaitMainQueue(turns: 2)

        #expect(display.presentCount == 2)
        #expect(display.dismissCount == 1)
        #expect(firstCompletions == [false])
        #expect(secondCompletions.isEmpty)
        #expect(display.onScreen == "second")
    }

    @Test("A discard right after a show starts closes that show")
    func discardRightAfterAShowStartsClosesIt() async {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)
        var completions: [Bool] = []

        present(on: manager, id: "just-started", onCompleted: { completions.append($0) })
        manager.discardActiveInApp()
        await awaitMainQueue(turns: 2)

        #expect(completions == [true])
        #expect(display.onScreen == nil)
    }

    @Test("A late close from a show that is no longer on screen leaves the show on screen up")
    func lateCloseFromAReplacedShowLeavesTheCurrentShowUp() async {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)
        var secondCompletions: [Bool] = []

        present(on: manager, id: "first")
        await awaitMainQueue()
        let firstClose = display.receivedOnClose
        present(on: manager, id: "second", onCompleted: { secondCompletions.append($0) })
        await awaitMainQueue()

        firstClose?()
        await awaitMainQueue(turns: 2)

        #expect(display.onScreen == "second")
        #expect(secondCompletions.isEmpty)
    }

    @Test("A replaced show never reports itself on screen")
    func replacedShowNeverReportsItselfOnScreen() async {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)
        var reported: [String] = []

        present(on: manager, id: "first", onPresented: { reported.append("first") })
        await awaitMainQueue()
        let firstPresented = display.receivedOnPresented
        present(on: manager, id: "second", onPresented: { reported.append("second") })
        await awaitMainQueue()

        firstPresented?()
        display.receivedOnPresented?()

        #expect(reported == ["second"])
    }

    @Test("A show that closes itself while it is being presented leaves no window behind and reports its error once")
    func showClosingItselfWhilePresentedLeavesNoWindow() async {
        let display = PresentationDisplaySpy()
        display.closesWhilePresenting = true
        let manager = InAppPresentationManager(displayUseCase: display)
        var completions: [Bool] = []
        var errors = 0

        present(on: manager, id: "broken-layer", onCompleted: { completions.append($0) }, onError: { _ in errors += 1 })
        await awaitMainQueue(turns: 3)

        #expect(display.onScreen == nil)
        #expect(errors == 1)
        #expect(completions.isEmpty)
    }

    @Test("The screen counts as taken from the moment a show starts until its completion has run")
    func screenIsTakenUntilTheCompletionHasRun() async {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)

        present(on: manager, id: "taken")
        #expect(manager.isPresenting)

        display.receivedOnClose?()
        #expect(manager.isPresenting)

        await awaitMainQueue()
        #expect(!manager.isPresenting)
    }

    @Test("A show that fails reports its error and not a close, and frees the screen")
    func failingShowReportsItsErrorAndNotAClose() async {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)
        var completions: [Bool] = []
        var errors = 0

        present(on: manager, id: "failing", onCompleted: { completions.append($0) }, onError: { _ in errors += 1 })
        display.receivedOnError?(.webviewLoadFailed("load failed"))
        display.receivedOnClose?()
        await awaitMainQueue(turns: 2)

        #expect(errors == 1)
        #expect(completions.isEmpty)
        #expect(!manager.isPresenting)
    }

    @Test("A late error from a replaced show leaves the screen to the show that replaced it")
    func lateErrorFromAReplacedShowLeavesTheScreenTaken() async {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)

        present(on: manager, id: "first")
        let firstError = display.receivedOnError
        present(on: manager, id: "second")
        await awaitMainQueue()

        firstError?(.webviewLoadFailed("late"))
        await awaitMainQueue()

        #expect(manager.isPresenting)
        #expect(display.onScreen == "second")
    }

    @Test("A show whose window never comes up frees the screen by the time its error is reported, and takes its window down")
    func errorAloneFreesTheScreen() async {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)
        var completions: [Bool] = []
        var screenTakenWhenTheErrorArrived: [Bool] = []

        present(on: manager,
                id: "no-window",
                onCompleted: { completions.append($0) },
                onError: { _ in screenTakenWhenTheErrorArrived.append(manager.isPresenting) })
        display.receivedOnError?(.failedToLoadWindow)
        await awaitMainQueue(turns: 2)

        #expect(screenTakenWhenTheErrorArrived == [false])
        #expect(display.onScreen == nil)
        #expect(completions.isEmpty)
    }

    enum Ending: CaseIterable {
        case close
        case discard
    }

    @Test("A show that is closing never reports itself on screen", arguments: Ending.allCases)
    func closingShowNeverReportsItselfOnScreen(ending: Ending) async {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)
        var reported = 0

        present(on: manager, id: "closing", onPresented: { reported += 1 })
        let presented = display.receivedOnPresented
        switch ending {
        case .close:
            display.receivedOnClose?()
        case .discard:
            manager.discardActiveInApp()
        }
        presented?()
        await awaitMainQueue()

        #expect(reported == 0)
    }

    @Test("A show started while the previous one is closing replaces it without closing it again")
    func showStartedWhileThePreviousIsClosingReplacesItOnce() async {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)
        var firstCompletions: [Bool] = []

        present(on: manager, id: "first", onCompleted: { firstCompletions.append($0) })
        display.receivedOnClose?()
        present(on: manager, id: "second")
        await awaitMainQueue(turns: 2)

        #expect(display.dismissCount == 1)
        #expect(firstCompletions == [false])
        #expect(display.onScreen == "second")
        #expect(manager.isPresenting)
    }

    @Test("The test apps' session erase discards the show on screen, like a session reset")
    func testAppsSessionEraseDiscardsTheShowOnScreen() async {
        let display = PresentationDisplaySpy()
        let manager = InAppPresentationManager(displayUseCase: display)
        var completions: [Bool] = []

        present(on: manager, id: "on-screen", onCompleted: { completions.append($0) })
        Mindbox.shared.perform(NSSelectorFromString("eraseSessionStorage"))
        await awaitMainQueue(turns: 2)

        #expect(completions == [true])
        #expect(!manager.isPresenting)
    }

    private func present(on manager: InAppPresentationManager,
                         id: String,
                         onPresented: @escaping () -> Void = {},
                         onCompleted: @escaping (Bool) -> Void = { _ in },
                         onError: @escaping (InAppPresentationError) -> Void = { _ in }) {
        manager.present(inAppFormData: Self.formData(id: id),
                        onPresented: onPresented,
                        onTapAction: { _, _ in },
                        onPresentationCompleted: onCompleted,
                        onError: onError)
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

@Suite("The host keeps its key window while an in-app is up", .tags(.inAppSchedule), .serialized)
@MainActor
struct InAppKeyWindowTests {

    @Test("Key goes back to the host before the tap reaches it, toward the window noted when the show began")
    func keyGoesBackBeforeTheTap() throws {
        let display = PresentationDisplaySpy()
        let returner = KeyWindowReturnerSpy()
        let hostWindow = UIWindow(frame: .zero)
        returner.hostWindow = hostWindow
        let manager = InAppPresentationManager(displayUseCase: display, keyWindowReturner: returner)
        var tapped: [URL?] = []

        manager.present(inAppFormData: Self.formData(id: "tapped"),
                        onPresented: {},
                        onTapAction: { url, _ in
                            returner.events.append("tap")
                            tapped.append(url)
                        },
                        onPresentationCompleted: { _ in },
                        onError: { _ in })
        let tap = try #require(display.receivedOnTapAction)
        tap(URL(string: "app://catalog"), "payload")

        #expect(returner.events == ["returnKey", "tap"])
        #expect(returner.preferred.count == 1)
        #expect(returner.preferred.first.flatMap { $0 } === hostWindow)
        #expect(tapped == [URL(string: "app://catalog")])
        withExtendedLifetime(manager) {}
    }

    @Test("Our window does not take key on its own")
    func inAppWindowRefusesKey() {
        guard #available(iOS 15.0, *) else { return }
        let (host, ours) = makeWindows()
        defer { hide(host, ours) }

        ours.makeKey()

        #expect(host.isKeyWindow)
        #expect(!ours.isKeyWindow)
    }

    @Test("Allowed key for a shake, our window takes it")
    func inAppWindowTakesKeyWhenAllowed() {
        let (host, ours) = makeWindows()
        defer { hide(host, ours) }

        ours.allowsKey = true
        ours.makeKey()

        #expect(ours.isKeyWindow)
    }

    @Test("Key goes back to the host window noted when the show began")
    func keyGoesBackToTheNotedWindow() {
        let (host, ours) = makeWindows()
        defer { hide(host, ours) }
        ours.allowsKey = true
        ours.makeKey()

        InAppKeyWindowReturner(windows: { [host, ours] }).returnKeyToHost(preferring: host)

        #expect(host.isKeyWindow)
    }

    @Test("With no noted window, key goes to the host's window of the same scene")
    func keyGoesBackToTheHostWindowOfTheScene() {
        let (host, ours) = makeWindows()
        defer { hide(host, ours) }
        ours.allowsKey = true
        ours.makeKey()

        InAppKeyWindowReturner(windows: { [host, ours] }).returnKeyToHost(preferring: nil)

        #expect(!ours.isKeyWindow)
        #expect(host.isKeyWindow)
    }

    @Test("A hidden noted window is passed over")
    func hiddenNotedWindowIsPassedOver() {
        let (host, ours) = makeWindows()
        let gone = UIWindow(frame: UIScreen.main.bounds)
        defer { hide(host, ours, gone) }
        ours.allowsKey = true
        ours.makeKey()

        InAppKeyWindowReturner(windows: { [host, ours, gone] }).returnKeyToHost(preferring: gone)

        #expect(!gone.isKeyWindow)
        #expect(host.isKeyWindow)
    }

    @Test("The host's key window is not ours")
    func hostKeyWindowSkipsOurs() {
        let (host, ours) = makeWindows()
        defer { hide(host, ours) }
        ours.allowsKey = true
        ours.makeKey()

        #expect(InAppKeyWindowReturner(windows: { [host, ours] }).hostKeyWindow() !== ours)
    }

    @Test("Nothing moves while the host already holds key")
    func nothingMovesWhileTheHostHoldsKey() {
        let (host, ours) = makeWindows()
        defer { hide(host, ours) }

        InAppKeyWindowReturner(windows: { [host, ours] }).returnKeyToHost(preferring: nil)

        #expect(host.isKeyWindow)
        #expect(!ours.isKeyWindow)
    }

    // MARK: Helpers

    private func makeWindows() -> (host: UIWindow, ours: MindboxInAppWindow) {
        let host = UIWindow(frame: UIScreen.main.bounds)
        host.rootViewController = UIViewController()
        host.makeKeyAndVisible()
        let ours = MindboxInAppWindow(frame: UIScreen.main.bounds)
        ours.rootViewController = UIViewController()
        ours.windowLevel = .normal + 3
        ours.isHidden = false
        return (host, ours)
    }

    private func hide(_ windows: UIWindow...) {
        windows.forEach { $0.isHidden = true }
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

private final class KeyWindowReturnerSpy: InAppKeyWindowReturning {
    var hostWindow: UIWindow?
    var events: [String] = []
    private(set) var preferred: [UIWindow?] = []

    func hostKeyWindow() -> UIWindow? { hostWindow }

    func returnKeyToHost(preferring preferred: UIWindow?) {
        self.preferred.append(preferred)
        events.append("returnKey")
    }
}
