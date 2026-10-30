//
//  InappScheduleManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 03.07.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import QuartzCore
import MindboxLogger
import UIKit

internal struct ScheduledInapp {
    let inapp: InAppFormData
    let timer: DispatchSourceTimer
    let processingDuration: TimeInterval
    var holdsSlot = false
}

protocol InappScheduleManagerProtocol {
    var delegate: InAppMessagesDelegate? { get set }
    func scheduleInApp(_ inAppFormData: InAppFormData, processingDuration: TimeInterval)

    func showInAppNow(_ inAppFormData: InAppFormData,
                      processingDuration: TimeInterval,
                      proceedIf requesterIsActive: @escaping () -> Bool,
                      completion: @escaping (Result<Void, InappShowNowError>) -> Void)
}

enum InappShowNowError: Error {
    case requesterGone
    case appInBackground
    case presentationFailed(InAppPresentationError)
}

final class InappScheduleManager: InappScheduleManagerProtocol {
    
    let presentationManager: InAppPresentationManagerProtocol
    let budget: InappShowBudgeting
    let accountant: InappShowAccounting
    let failureManager: InappShowFailureManagerProtocol
    private let isInBackground: () -> Bool
    private let now: () -> Date

    let queue = DispatchQueue(label: "com.Mindbox.delayedInAppManager", qos: .userInitiated)
    var inappsByPresentationTime: [TimeInterval: [ScheduledInapp]] = [:]

    init(presentationManager: InAppPresentationManagerProtocol,
         budget: InappShowBudgeting,
         accountant: InappShowAccounting,
         failureManager: InappShowFailureManagerProtocol,
         isInBackground: @escaping () -> Bool = { UIApplication.shared.applicationState == .background },
         now: @escaping () -> Date = Date.init) {
        self.presentationManager = presentationManager
        self.budget = budget
        self.accountant = accountant
        self.failureManager = failureManager
        self.isInBackground = isInBackground
        self.now = now
        addObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    weak var delegate: InAppMessagesDelegate?

    func scheduleInApp(_ inapp: InAppFormData, processingDuration: TimeInterval) {
        let delay = TimeInterval.delay(fromTimeSpan: inapp.delayTime)
        let presentationTime = now().addingTimeInterval(delay).timeIntervalSince1970

        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer.schedule(deadline: .now() + delay, repeating: .never, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }

                if self.isInBackground() {
                    self.holdEligibleInapp(presentationTime)
                } else {
                    self.showEligibleInapp(presentationTime)
                }
            }
        }

        let scheduledInapp = ScheduledInapp(inapp: inapp, timer: timer, processingDuration: processingDuration)

        queue.async {
            self.inappsByPresentationTime[presentationTime, default: []].append(scheduledInapp)
            timer.resume()
            Logger.common(message: "[InappScheduleManager] Scheduled \(inapp.inAppId) at \(presentationTime.asReadableDateTime) priority=\(inapp.isPriority) processingDuration=\(processingDuration.toTimeSpan())")
        }
    }

    func showInAppNow(_ inapp: InAppFormData,
                      processingDuration: TimeInterval,
                      proceedIf requesterIsActive: @escaping () -> Bool,
                      completion: @escaping (Result<Void, InappShowNowError>) -> Void) {
        DispatchQueue.main.async {
            guard requesterIsActive() else {
                Logger.common(message: "[InappScheduleManager] Not showing \(inapp.inAppId): whoever asked for it is gone")
                completion(.failure(.requesterGone))
                return
            }
            guard !self.isInBackground() else {
                Logger.common(message: "[InappScheduleManager] Not showing \(inapp.inAppId): the app is in the background")
                completion(.failure(.appInBackground))
                return
            }

            self.presentRequestedInapp(inapp, processingDuration: processingDuration) { outcome in
                completion(outcome.mapError(InappShowNowError.presentationFailed))
            }
        }
    }
}

internal extension InappScheduleManager {
    func showEligibleInapp(_ presentationTime: TimeInterval) {
        queue.async {
            self.showWinner(at: presentationTime)
        }
    }

    // On queue.
    private func showWinner(at presentationTime: TimeInterval) {
        guard let winner = takeWinner(at: presentationTime) else { return }

        DispatchQueue.main.async {
            self.presentIfScreenIsFree(winner)
        }
    }

    // On main.
    private func presentIfScreenIsFree(_ winner: ScheduledInapp) {
        guard !presentationManager.isPresenting else {
            Logger.common(message: "[InappScheduleManager] Another in-app is already being shown, skipping \(winner.inapp.inAppId)",
                          level: .debug, category: .inAppMessages)
            giveBackSlot(of: winner)
            return
        }

        let reservation = reserveSlot(for: winner.inapp)
        guard reservation != .refused else { return }

        presentInapp(winner.inapp,
                     stopwatch: ForegroundStopwatch(),
                     processingDuration: winner.processingDuration,
                     holdsSlot: winner.holdsSlot || reservation == .granted)
    }

    // On main: isPresenting is read here, before the hop to queue.
    func holdEligibleInapp(_ presentationTime: TimeInterval) {
        let isScreenTaken = presentationManager.isPresenting
        queue.async {
            guard var winner = self.takeWinner(at: presentationTime) else { return }

            guard !isScreenTaken else {
                Logger.common(message: "[InappScheduleManager] Another in-app is on screen, dropping \(winner.inapp.inAppId)",
                              level: .debug, category: .inAppMessages)
                self.giveBackSlot(of: winner)
                return
            }

            let reservation = self.reserveSlot(for: winner.inapp)
            guard reservation != .refused else { return }

            winner.holdsSlot = winner.holdsSlot || reservation == .granted
            self.inappsByPresentationTime[presentationTime] = [winner]
            Logger.common(message: "[InappScheduleManager] \(winner.inapp.inAppId) waits for the foreground",
                          level: .debug, category: .inAppMessages)
        }
    }

    private func takeWinner(at presentationTime: TimeInterval) -> ScheduledInapp? {
        guard let scheduled = inappsByPresentationTime.removeValue(forKey: presentationTime) else { return nil }

        for scheduledInapp in scheduled {
            scheduledInapp.timer.cancel()
        }
        return scheduled.sorted { $0.inapp.isPriority && !$1.inapp.isPriority }.first
    }

    private func giveBackSlot(of scheduled: ScheduledInapp) {
        guard scheduled.holdsSlot else { return }

        budget.release(.overlay(scheduled.inapp.inAppId))
    }

    private func reserveSlot(for inapp: InAppFormData) -> InappShowReservationOutcome {
        budget.reserve(.overlay(inapp.inAppId), inAppId: inapp.inAppId, isPriority: inapp.isPriority, frequency: inapp.frequency)
    }

    private func trackShow(_ inapp: InAppFormData, timeToDisplay: TimeInterval) {
        accountant.recordShow(InappShow(inAppId: inapp.inAppId,
                                        frequency: inapp.frequency,
                                        tags: inapp.tags,
                                        timeToDisplay: timeToDisplay))
    }

    private func trackDismissal(_ inapp: InAppFormData) {
        accountant.recordCooldown(frequency: inapp.frequency)
    }

    private func presentRequestedInapp(_ inapp: InAppFormData,
                                       processingDuration: TimeInterval,
                                       outcome: @escaping (Result<Void, InAppPresentationError>) -> Void) {
        Logger.common(message: "[InappScheduleManager] Showing \(inapp.inAppId) on request, past the queue and its limits")
        presentInapp(inapp, stopwatch: ForegroundStopwatch(), processingDuration: processingDuration, outcome: outcome)
    }

    func presentInapp(_ inapp: InAppFormData,
                      stopwatch: ForegroundStopwatch,
                      processingDuration: TimeInterval = 0,
                      holdsSlot: Bool = false,
                      outcome: ((Result<Void, InAppPresentationError>) -> Void)? = nil) {
        present(
            inapp,
            holdsSlot: holdsSlot,
            onPresented: {
                let presentationTime = stopwatch.elapsed
                stopwatch.stop()
                let timeToDisplay = processingDuration + presentationTime
                Logger.common(message: "[InAppMetric] inappId=\(inapp.inAppId) processingTime=\(processingDuration.toTimeSpan()) "
                    + "presentationTime=\(presentationTime.toTimeSpan()) timeToDisplay=\(timeToDisplay.toTimeSpan())")
                self.trackShow(inapp, timeToDisplay: timeToDisplay)
                outcome?(.success(()))
            },
            onDismissed: {
                self.trackDismissal(inapp)
            },
            onFailed: { error in
                outcome?(.failure(error))
            }
        )
    }

    // On main.
    private func present(_ inapp: InAppFormData,
                         holdsSlot: Bool,
                         onPresented: @escaping () -> Void,
                         onDismissed: @escaping () -> Void,
                         onFailed: @escaping (InAppPresentationError) -> Void) {
        SessionTemporaryStorage.shared.lastInappClickedID = nil
        var didHandleOnError = false
        var didPresent = false

        Logger.common(message: "[InappScheduleManager] Showing in-app \(inapp.inAppId)")

        presentationManager.present(
            inAppFormData: inapp,
            onPresented: {
                guard !didPresent else { return }
                didPresent = true
                onPresented()
            },
            onTapAction: { [delegate] url, payload in
                delegate?.inAppMessageTapAction(
                    id: inapp.inAppId,
                    url: url,
                    payload: payload
                )
            },
            onPresentationCompleted: { [delegate] wasDiscarded in
                if !wasDiscarded {
                    delegate?.inAppMessageDismissed(id: inapp.inAppId)
                }
                if didPresent {
                    if !wasDiscarded {
                        onDismissed()
                    }
                    return
                }

                if holdsSlot {
                    self.budget.release(.overlay(inapp.inAppId))
                }
                onFailed(.failed("[InappScheduleManager] Closed before it was on screen."))
            },
            onError: { error in
                guard !didHandleOnError else {
                    return
                }
                didHandleOnError = true

                if holdsSlot {
                    self.budget.release(.overlay(inapp.inAppId))
                }
                self.failureManager.sendFailure(inappId: inapp.inAppId,
                                                reason: error.failureReason,
                                                details: error.failureDetails,
                                                tags: inapp.tags)
                guard !didPresent else { return }
                onFailed(error)
            }
        )
    }
    
    func addObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.checkExpiredInapps()
        }
    }
    
    func checkExpiredInapps() {
        queue.async {
            guard SessionTemporaryStorage.shared.isInitializationCalled else { return }

            if let configExpirationTime = SessionTemporaryStorage.shared.configSessionExpirationTime, configExpirationTime < self.now() {
                for scheduledInapp in self.inappsByPresentationTime.values.joined() {
                    scheduledInapp.timer.cancel()
                    self.giveBackSlot(of: scheduledInapp)
                }
                self.inappsByPresentationTime = [:]
                Logger.common(message: "[InappScheduleManager] Session expired, canceling all scheduled in-app messages", level: .debug, category: .inAppMessages)
                return
            }

            let now = self.now().timeIntervalSince1970
            let expiredTimes = self.inappsByPresentationTime.keys.filter { $0 <= now }
            guard let earliestTime = expiredTimes.min() else { return }

            for expiredTime in expiredTimes where expiredTime != earliestTime {
                for scheduledInapp in self.inappsByPresentationTime.removeValue(forKey: expiredTime) ?? [] {
                    scheduledInapp.timer.cancel()
                    self.giveBackSlot(of: scheduledInapp)
                }
            }
            self.showWinner(at: earliestTime)
        }
    }
}
