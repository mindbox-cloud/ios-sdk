//
//  InAppCoreManagerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@_spi(Internal) @testable import Mindbox

/// The push side of embedded blocks at its source: an operation the pipeline agreed to handle is
/// announced, one the config never mentions wakes nobody.
@Suite("In-app core manager operation announcement", .tags(.embeddedBlocks))
struct InAppCoreManagerTests {

    private final class ConfigManagerStub: InAppConfigurationManagerProtocol {
        weak var delegate: InAppConfigurationDelegate?

        func prepareConfiguration() {}
        func handleInapps(event: ApplicationEvent?, _ completion: @escaping (InAppFormData?) -> Void) {
            completion(nil)
        }
        func selectInappForPlace(_ place: String, trigger: ApplicationEvent?, _ completion: @escaping (InAppTransitionData?) -> Void) {
            completion(nil)
        }
        func getInAppById(_ id: String, _ completion: @escaping (InAppTransitionData?) -> Void) {
            completion(nil)
        }
        func getRenderableInappIds(_ ids: [String], _ completion: @escaping (FeedAnswer) -> Void) {
            completion(.nothing)
        }
        func getInAppToShowById(_ id: String, params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) {
            completion(nil)
        }
        func getEmbeddedPlaces(_ completion: @escaping ([String: Set<String>]?) -> Void) {
            completion(nil)
        }
        func resetInappManager() {}
    }

    private final class SchedulerStub: InappScheduleManagerProtocol {
        weak var delegate: InAppMessagesDelegate?

        func scheduleInApp(_ inAppFormData: InAppFormData, processingDuration: TimeInterval) {}
        func showInAppNow(_ inAppFormData: InAppFormData) {}
    }

    private let queue = DispatchQueue(label: "test.core-manager.events")
    private let coreManager: InAppCoreManager

    init() {
        TestConfiguration.configure()
        SessionTemporaryStorage.shared.erase()

        coreManager = InAppCoreManager(configManager: ConfigManagerStub(),
                                       inappScheduler: SchedulerStub(),
                                       serialQueue: queue)
        coreManager.didPreparedConfiguration()
    }

    /// Collects every announced operation for the test's lifetime.
    private final class AnnouncementSpy {
        private(set) var events: [ApplicationEvent] = []
        private var token: NSObjectProtocol?

        init() {
            token = NotificationCenter.default.addObserver(forName: .inAppOperationOccurred,
                                                           object: nil,
                                                           queue: nil) { [weak self] notification in
                guard let event = notification.object as? ApplicationEvent else { return }
                self?.events.append(event)
            }
        }

        deinit {
            if let token {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }

    @Test("A handled operation is announced with its event")
    func handledOperationIsAnnounced() {
        SessionTemporaryStorage.shared.observedCustomOperations.insert("block.refresh.operation")
        let spy = AnnouncementSpy()
        let event = ApplicationEvent(name: "block.refresh.operation", model: nil)

        coreManager.sendEvent(.applicationEvent(event))
        queue.sync {}

        #expect(spy.events.count == 1)
        #expect(spy.events.first === event)
    }

    /// The gate stays in front of the announcement: an operation the config never mentions cannot
    /// bring content to any place, so no block should be woken to ask.
    @Test("An operation the config does not know is not announced")
    func unknownOperationIsNotAnnounced() {
        let spy = AnnouncementSpy()

        coreManager.sendEvent(.applicationEvent(ApplicationEvent(name: "operation.nobody.knows", model: nil)))
        queue.sync {}

        #expect(spy.events.isEmpty)
    }

    /// Blocks pull at start on their own; announcing the start would make every block resolve twice.
    @Test("The start event is not announced")
    func startIsNotAnnounced() {
        let spy = AnnouncementSpy()

        coreManager.sendEvent(.start)
        queue.sync {}

        #expect(spy.events.isEmpty)
    }
}
