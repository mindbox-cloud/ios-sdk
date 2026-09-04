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
    /// The moment came in the background and the in-app took its slot to wait for the foreground with it.
    var holdsSlot = false
}

protocol InappScheduleManagerProtocol {
    var delegate: InAppMessagesDelegate? { get set }
    func scheduleInApp(_ inAppFormData: InAppFormData, processingDuration: TimeInterval)

    /// Past the queue and every limit — a direct call is invited, and a tap that does nothing is a
    /// defect. Only `Inapp.Show` goes out: targeting was sent when the selection offered the in-app.
    /// `processingDuration` is the caller's time since the tap; it counts into `timeToDisplay` like the overlay pass's.
    /// `completion` answers once: the window is on screen, or the error that kept it off.
    func showInAppNow(_ inAppFormData: InAppFormData,
                      processingDuration: TimeInterval,
                      completion: @escaping (Result<Void, InAppPresentationError>) -> Void)
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
            // The application state is UIKit's to answer, on the main queue.
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
                      completion: @escaping (Result<Void, InAppPresentationError>) -> Void) {
        DispatchQueue.main.async {
            // Dismissal completes the closed show on the next main-queue turn; presenting is deferred
            // behind it so the lock is released before the new show takes it.
            self.presentationManager.dismissActiveInApp()

            DispatchQueue.main.async {
                self.presentRequestedInapp(inapp, processingDuration: processingDuration, outcome: completion)
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

    /// On `queue`.
    private func showWinner(at presentationTime: TimeInterval) {
        guard let winner = takeWinner(at: presentationTime) else { return }

        guard !SessionTemporaryStorage.shared.isPresentingInAppMessage else {
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

    /// The moment came in the background. The winner takes its slot now, in sync with Android, and waits
    /// under its time to be presented at the foreground; refused, or behind an in-app on screen, it is dropped.
    func holdEligibleInapp(_ presentationTime: TimeInterval) {
        queue.async {
            guard var winner = self.takeWinner(at: presentationTime) else { return }

            guard !SessionTemporaryStorage.shared.isPresentingInAppMessage else {
                Logger.common(message: "[InappScheduleManager] Another in-app is on screen, dropping \(winner.inapp.inAppId)",
                              level: .debug, category: .inAppMessages)
                self.giveBackSlot(of: winner)
                return
            }

            let reservation = self.reserveSlot(for: winner.inapp)
            guard reservation != .refused else { return }

            winner.holdsSlot = winner.holdsSlot || reservation == .granted
            self.inappsByPresentationTime[presentationTime] = [winner]
            Logger.common(message: "[InappScheduleManager] \(winner.inapp.inAppId) waits for the foreground with its slot taken",
                          level: .debug, category: .inAppMessages)
        }
    }

    /// The moment's winner, the moment itself gone whether it shows or not: a show missed behind another
    /// in-app is missed, by decision — no queue, no re-arm.
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

    /// The cooldown is written a second time on dismissal, so that an app killed while the in-app was
    /// on screen still leaves the interval counted from a real moment.
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

    private func present(_ inapp: InAppFormData,
                         holdsSlot: Bool,
                         onPresented: @escaping () -> Void,
                         onDismissed: @escaping () -> Void,
                         onFailed: @escaping (InAppPresentationError) -> Void) {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        SessionTemporaryStorage.shared.lastInappClickedID = nil
        var didHandleOnError = false
        // Both flip on the main queue: the presentation manager delivers every callback there.
        var didPresent = false

        Logger.common(message: "[InappScheduleManager] Showing in-app \(inapp.inAppId)")

        presentationManager.present(
            inAppFormData: inapp,
            onPresented: {
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
            onPresentationCompleted: { [delegate] in
                SessionTemporaryStorage.shared.isPresentingInAppMessage = false
                delegate?.inAppMessageDismissed(id: inapp.inAppId)
                if didPresent {
                    onDismissed()
                } else if holdsSlot {
                    self.budget.release(.overlay(inapp.inAppId))
                }
            },
            onError: { error in
                guard !didHandleOnError else {
                    return
                }
                didHandleOnError = true

                SessionTemporaryStorage.shared.isPresentingInAppMessage = false
                if holdsSlot {
                    self.budget.release(.overlay(inapp.inAppId))
                }
                self.failureManager.addFailure(
                    inappId: inapp.inAppId,
                    reason: error.failureReason,
                    details: error.failureDetails,
                    tags: inapp.tags
                )
                self.failureManager.sendFailures()
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
