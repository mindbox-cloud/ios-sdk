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
    func showInAppNow(_ inAppFormData: InAppFormData)
}

final class InappScheduleManager: InappScheduleManagerProtocol {
    
    let presentationManager: InAppPresentationManagerProtocol
    let presentationValidator: InAppPresentationValidatorProtocol
    let trackingService: InAppTrackingServiceProtocol
    let tracker: InAppMessagesTrackerProtocol
    let failureManager: InappShowFailureManagerProtocol
    
    let queue = DispatchQueue(label: "com.Mindbox.delayedInAppManager", qos: .userInitiated)
    var inappsByPresentationTime: [TimeInterval: [ScheduledInapp]] = [:]
    
    init(presentationManager: InAppPresentationManagerProtocol,
         presentationValidator: InAppPresentationValidatorProtocol,
         trackingService: InAppTrackingServiceProtocol,
         tracker: InAppMessagesTrackerProtocol,
         failureManager: InappShowFailureManagerProtocol) {
        self.presentationManager = presentationManager
        self.presentationValidator = presentationValidator
        self.trackingService = trackingService
        self.tracker = tracker
        self.failureManager = failureManager
        addObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    weak var delegate: InAppMessagesDelegate?
    
    func scheduleInApp(_ inapp: InAppFormData, processingDuration: TimeInterval) {
        let delay = getDelay(inapp.delayTime)
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

    func showInAppNow(_ inapp: InAppFormData) {
        DispatchQueue.main.async {
            // Dismissal completes the closed show on the next main-queue turn; presenting is deferred
            // behind it so the lock is released before the new show takes it.
            self.presentationManager.dismissActiveInApp()

            DispatchQueue.main.async {
                self.presentRequestedInapp(inapp)
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
            
            self.failureManager.clearFailures()
            self.inappsByPresentationTime.removeValue(forKey: presentationTime)
        }
    }
    
    private func trackShow(_ inapp: InAppFormData, timeToDisplay: String) {
        do {
            try tracker.trackView(id: inapp.inAppId, timeToDisplay: timeToDisplay, tags: inapp.tags)
        } catch {
            Logger.common(message: "[InappScheduleManager] Track InApp.View failed with error: \(error)", level: .error, category: .notification)
        }

        guard InappFrequency.countsShows(inapp.frequency) else { return }

        trackingService.trackInAppShown(id: inapp.inAppId)
        trackingService.saveInappStateChange()
    }

    /// The cooldown is written a second time on dismissal, so that an app killed while the in-app was
    /// on screen still leaves the interval counted from a real moment.
    private func trackDismissal(_ inapp: InAppFormData) {
        guard InappFrequency.countsShows(inapp.frequency) else { return }

        trackingService.saveInappStateChange()
    }

    private func presentRequestedInapp(_ inapp: InAppFormData) {
        Logger.common(message: "[InappScheduleManager] Showing \(inapp.inAppId) on request, past the queue and its limits")

        let stopwatch = ForegroundStopwatch()
        present(
            inapp,
            onPresented: {
                let presentationTime = stopwatch.elapsed
                stopwatch.stop()
                let timeToDisplayString = presentationTime.toTimeSpan()
                Logger.common(message: "[InAppMetric] inappId=\(inapp.inAppId) presentationTime=\(timeToDisplayString) timeToDisplay=\(timeToDisplayString)")
                self.trackShow(inapp, timeToDisplay: timeToDisplayString)
            },
            onDismissed: {
                self.trackDismissal(inapp)
            }
        )
    }

    func presentInapp(_ inapp: InAppFormData, stopwatch: ForegroundStopwatch, processingDuration: TimeInterval = 0) {
        present(
            inapp,
            onPresented: {
                let presentationTime = stopwatch.elapsed
                stopwatch.stop()
                let timeToDisplay = processingDuration + presentationTime
                let timeToDisplayString = timeToDisplay.toTimeSpan()
                Logger.common(message: "[InAppMetric] inappId=\(inapp.inAppId) processingTime=\(processingDuration.toTimeSpan()) presentationTime=\(presentationTime.toTimeSpan()) timeToDisplay=\(timeToDisplayString)")
                self.trackShow(inapp, timeToDisplay: timeToDisplayString)
                self.failureManager.clearFailures()
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
    
    func getDelay(_ time: String?) -> TimeInterval {
        let delayTimeStr = time
        let delayMilis = (try? delayTimeStr?.parseTimeSpanToMillis()) ?? 0
        return TimeInterval(delayMilis) / 1000
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
