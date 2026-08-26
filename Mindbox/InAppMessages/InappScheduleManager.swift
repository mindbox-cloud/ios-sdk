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
}

protocol InappScheduleManagerProtocol {
    var delegate: InAppMessagesDelegate? { get set }
    func scheduleInApp(_ inAppFormData: InAppFormData, processingDuration: TimeInterval)

    /// Past the queue and every limit — a direct call is invited, and a tap that does nothing is a
    /// defect. Only `Inapp.Show` goes out: targeting was sent when the selection offered the in-app.
    /// `processingDuration` is the caller's time since the tap — fetching and building the form counts
    /// into `timeToDisplay`, like the overlay's pass does.
    func showInAppNow(_ inAppFormData: InAppFormData, processingDuration: TimeInterval)
}

final class InappScheduleManager: InappScheduleManagerProtocol {
    
    let presentationManager: InAppPresentationManagerProtocol
    let presentationValidator: InAppPresentationValidatorProtocol
    let accountant: InappShowAccounting
    let failureManager: InappShowFailureManagerProtocol
    
    let queue = DispatchQueue(label: "com.Mindbox.delayedInAppManager", qos: .userInitiated)
    var inappsByPresentationTime: [TimeInterval: [ScheduledInapp]] = [:]
    
    init(presentationManager: InAppPresentationManagerProtocol,
         presentationValidator: InAppPresentationValidatorProtocol,
         accountant: InappShowAccounting,
         failureManager: InappShowFailureManagerProtocol) {
        self.presentationManager = presentationManager
        self.presentationValidator = presentationValidator
        self.accountant = accountant
        self.failureManager = failureManager
        addObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    weak var delegate: InAppMessagesDelegate?
    
    func scheduleInApp(_ inapp: InAppFormData, processingDuration: TimeInterval) {
        let delay = TimeInterval.delay(fromTimeSpan: inapp.delayTime)
        let presentationTime = Date().addingTimeInterval(delay).timeIntervalSince1970
        
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer.schedule(deadline: .now() + delay, repeating: .never, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .background {
                    Logger.common(message: "[InappScheduleManager] Skipping presentation of \(inapp.inAppId) because app is in background.")
                    return
                }
                
                self?.showEligibleInapp(presentationTime)
            }
        }
        
        let scheduledInapp = ScheduledInapp(inapp: inapp, timer: timer, processingDuration: processingDuration)
        
        queue.async {
            self.inappsByPresentationTime[presentationTime, default: []].append(scheduledInapp)
            timer.resume()
            Logger.common(message: "[InappScheduleManager] Scheduled \(inapp.inAppId) at \(presentationTime.asReadableDateTime) priority=\(inapp.isPriority) processingDuration=\(processingDuration.toTimeSpan())")
        }
    }

    func showInAppNow(_ inapp: InAppFormData, processingDuration: TimeInterval) {
        DispatchQueue.main.async {
            // Dismissal completes the closed show on the next main-queue turn; presenting is deferred
            // behind it so the lock is released before the new show takes it.
            self.presentationManager.dismissActiveInApp()

            DispatchQueue.main.async {
                self.presentRequestedInapp(inapp, processingDuration: processingDuration)
            }
        }
    }
}

internal extension InappScheduleManager {
    func showEligibleInapp(_ presentationTime: TimeInterval) {
        queue.async {
            guard let scheduledInapps = self.inappsByPresentationTime[presentationTime], !scheduledInapps.isEmpty else {
                return
            }
            
            let sortedScheduledInapps = scheduledInapps.sorted {
                $0.inapp.isPriority && !$1.inapp.isPriority
            }
            
            if let firstInapp = sortedScheduledInapps.first,
                self.presentationValidator.canPresentInApp(isPriority: firstInapp.inapp.isPriority,
                                                           frequency: firstInapp.inapp.frequency,
                                                           id: firstInapp.inapp.inAppId) {
                let stopwatch = ForegroundStopwatch()
                self.presentInapp(firstInapp.inapp, stopwatch: stopwatch, processingDuration: firstInapp.processingDuration)
            }
            
            for scheduledInapp in scheduledInapps {
                scheduledInapp.timer.cancel()
            }
            
            // Gone whether it showed or not: an in-app whose moment came while another was on screen
            // is neither queued behind it nor re-armed — a missed moment is missed, by decision.
            self.inappsByPresentationTime.removeValue(forKey: presentationTime)
        }
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

    private func presentRequestedInapp(_ inapp: InAppFormData, processingDuration: TimeInterval) {
        Logger.common(message: "[InappScheduleManager] Showing \(inapp.inAppId) on request, past the queue and its limits")
        presentInapp(inapp, stopwatch: ForegroundStopwatch(), processingDuration: processingDuration)
    }

    func presentInapp(_ inapp: InAppFormData, stopwatch: ForegroundStopwatch, processingDuration: TimeInterval = 0) {
        present(
            inapp,
            onPresented: {
                let presentationTime = stopwatch.elapsed
                stopwatch.stop()
                let timeToDisplay = processingDuration + presentationTime
                Logger.common(message: "[InAppMetric] inappId=\(inapp.inAppId) processingTime=\(processingDuration.toTimeSpan()) "
                    + "presentationTime=\(presentationTime.toTimeSpan()) timeToDisplay=\(timeToDisplay.toTimeSpan())")
                self.trackShow(inapp, timeToDisplay: timeToDisplay)
            },
            onDismissed: {
                self.trackDismissal(inapp)
            }
        )
    }

    private func present(_ inapp: InAppFormData,
                         onPresented: @escaping () -> Void,
                         onDismissed: @escaping () -> Void) {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        SessionTemporaryStorage.shared.lastInappClickedID = nil
        var didHandleOnError = false

        Logger.common(message: "[InappScheduleManager] Showing in-app \(inapp.inAppId)")

        presentationManager.present(
            inAppFormData: inapp,
            onPresented: onPresented,
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
                onDismissed()
            },
            onError: { error in
                guard !didHandleOnError else {
                    return
                }
                didHandleOnError = true

                SessionTemporaryStorage.shared.isPresentingInAppMessage = false
                self.failureManager.addFailure(
                    inappId: inapp.inAppId,
                    reason: error.failureReason,
                    details: error.failureDetails,
                    tags: inapp.tags
                )
                self.failureManager.sendFailures()
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
            
            if let configExpirationTime = SessionTemporaryStorage.shared.configSessionExpirationTime {
                if configExpirationTime < Date() {
                    
                    for scheduledInapps in self.inappsByPresentationTime.values {
                        for scheduledInapp in scheduledInapps {
                            scheduledInapp.timer.cancel()
                        }
                    }
                    
                    self.inappsByPresentationTime = [:]
                    Logger.common(message: "[InappScheduleManager] Session expired, canceling all scheduled in-app messages", level: .debug, category: .inAppMessages)
                    return
                }
            }
            
            let now = Date().timeIntervalSince1970
            let expiredInapps = self.inappsByPresentationTime.keys.filter { $0 <= now }
            if let earliestInapp = expiredInapps.min() {
                self.showEligibleInapp(earliestInapp)
                
                for expiredInapp in expiredInapps where expiredInapp != earliestInapp {
                    if let scheduledInapps = self.inappsByPresentationTime[expiredInapp] {
                        for scheduledInapp in scheduledInapps {
                            scheduledInapp.timer.cancel()
                        }
                    }
                    self.inappsByPresentationTime.removeValue(forKey: expiredInapp)
                }
            }
        }
    }
}
