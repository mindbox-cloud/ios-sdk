//
//  EmbeddedBlockMocks.swift
//  MindboxTests
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
@testable import Mindbox

extension EmbeddedBlockWebContent {

    static let stub = EmbeddedBlockWebContent(url: URL(string: "https://mindbox.ru/block.html")!)

    static let other = EmbeddedBlockWebContent(url: URL(string: "https://mindbox.ru/another-block.html")!)
}

/// A page without WebKit: tests decide what it tells the native side and when.
final class EmbeddedBlockPageMock: EmbeddedBlockPageHosting {

    let view = UIView()

    var onContentRendered: ((Int) -> Void)?

    var onLoadFailure: (() -> Void)?

    var onLoadFinish: (() -> Void)?

    var isUserPresent = true

    var loadCount = 0
    var reloadCount = 0
    var cancelCount = 0

    func load() {
        loadCount += 1
    }

    func reload() {
        reloadCount += 1
    }

    func cancel() {
        cancelCount += 1
    }

    /// The page reporting what it rendered — the one thing the provider listens for.
    func renderContent(count: Int) {
        onContentRendered?(count)
    }

    func failLoad() {
        onLoadFailure?()
    }

    func finishLoad() {
        onLoadFinish?()
    }
}

final class EmbeddedBlockReadinessOverridesMock: EmbeddedBlockReadinessOverriding {

    var treatsLoadedPageAsReady: Bool

    init(treatsLoadedPageAsReady: Bool = false) {
        self.treatsLoadedPageAsReady = treatsLoadedPageAsReady
    }
}

/// Counts how many pages were made and with what content: a reload must make a new one.
final class EmbeddedBlockPageFactoryMock {

    private(set) var pages: [EmbeddedBlockPageMock] = []
    private(set) var contents: [EmbeddedBlockWebContent] = []
    private(set) var ids: [String] = []

    var page: EmbeddedBlockPageMock? { pages.last }

    func make(_ id: String, _ content: EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting {
        ids.append(id)
        contents.append(content)
        let page = EmbeddedBlockPageMock()
        pages.append(page)
        return page
    }
}

final class EmbeddedBlockResolverMock: EmbeddedBlockResolving {

    var resolution: EmbeddedBlockResolution

    /// `true` — the answer does not arrive until the test calls `flush()`: this is how a resolve
    /// that lands after the block was stopped or reloaded is checked.
    var isDeferred = false

    private(set) var resolvedIds: [String] = []
    private(set) var forceRefreshHistory: [Bool] = []

    var resolveCount: Int { resolvedIds.count }

    private var pending: [(EmbeddedBlockResolution) -> Void] = []

    init(resolution: EmbeddedBlockResolution = .content(.stub)) {
        self.resolution = resolution
    }

    func resolve(_ id: String, forceRefresh: Bool, completion: @escaping (EmbeddedBlockResolution) -> Void) {
        resolvedIds.append(id)
        forceRefreshHistory.append(forceRefresh)

        if isDeferred {
            pending.append(completion)
        } else {
            completion(resolution)
        }
    }

    func flush() {
        let completions = pending
        pending = []
        completions.forEach { $0(resolution) }
    }
}

/// A clock that moves only when asked to. Monotonic seconds, matching the timeout's clock seam;
/// a negative `advance` models the backward jump a monotonic clock never makes.
final class TestClock {

    private(set) var now: TimeInterval = 1_000_000

    func advance(_ seconds: TimeInterval) {
        now += seconds
    }
}

/// A scheduler that never fires on its own: "time is up" is declared by the test.
///
/// Thanks to it the waiting budget is checked without a single sleep: both in its own tests and in
/// the tests of the container, which is handed the budget from outside.
final class TestScheduler {

    /// The delay of the last arm — which is the remainder of the budget given to the countdown.
    private(set) var lastDelay: TimeInterval?

    private var pending: [DispatchWorkItem] = []

    func schedule(_ delay: TimeInterval, _ work: DispatchWorkItem) {
        lastDelay = delay
        pending.append(work)
    }

    /// Performs the armed work, skipping what was cancelled: `pause()` and `reset()` cancel it
    /// exactly the way they would cancel work on a real queue.
    func fireAll() {
        let scheduled = pending
        pending = []
        scheduled.forEach { work in
            guard !work.isCancelled else { return }

            work.perform()
        }
    }
}

/// The waiting budget with a substituted clock, scheduler and notification center — everything
/// that makes it different from the real one, gathered in one place.
final class EmbeddedBlockTimeoutBed {

    let clock: TestClock
    let scheduler: TestScheduler

    /// One per bed: the background and the return from it must reach only this budget.
    let center: NotificationCenter

    let timeout: EmbeddedBlockReadyTimeout

    init(blockId: String = "block-id", duration: TimeInterval = 5) {
        let clock = TestClock()
        let scheduler = TestScheduler()
        let center = NotificationCenter()
        self.clock = clock
        self.scheduler = scheduler
        self.center = center
        timeout = EmbeddedBlockReadyTimeout(blockId: blockId,
                                            duration: duration,
                                            now: { clock.now },
                                            notificationCenter: center,
                                            schedule: { scheduler.schedule($0, $1) })
    }

    func enterBackground() {
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    func enterForeground() {
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }
}

/// The provider with all dependencies substituted — the shared rig for the provider and container
/// tests. The container is tested through a real provider: the single seam inside the block is the
/// page, and there is nothing else to substitute.
final class EmbeddedBlockTestBed {

    let resolver: EmbeddedBlockResolverMock
    let readinessOverrides: EmbeddedBlockReadinessOverridesMock
    let pageFactory: EmbeddedBlockPageFactoryMock
    let provider: EmbeddedBlockWebViewProvider

    var page: EmbeddedBlockPageMock? { pageFactory.page }

    init(id: String = "block-id",
         resolution: EmbeddedBlockResolution = .content(.stub),
         treatsLoadedPageAsReady: Bool = false) {
        let resolver = EmbeddedBlockResolverMock(resolution: resolution)
        let readinessOverrides = EmbeddedBlockReadinessOverridesMock(treatsLoadedPageAsReady: treatsLoadedPageAsReady)
        let pageFactory = EmbeddedBlockPageFactoryMock()

        self.resolver = resolver
        self.readinessOverrides = readinessOverrides
        self.pageFactory = pageFactory
        self.provider = EmbeddedBlockWebViewProvider(id: id,
                                                     resolver: resolver,
                                                     readinessOverrides: readinessOverrides,
                                                     makePage: { pageFactory.make($0, $1) })
    }
}

final class EmbeddedBlockViewDelegateMock: MindboxEmbeddedBlockViewDelegate {

    enum Event: Equatable {
        case loaded
        case failed
    }

    private(set) var events: [Event] = []

    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView) {
        events.append(.loaded)
    }

    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView) {
        events.append(.failed)
    }
}
