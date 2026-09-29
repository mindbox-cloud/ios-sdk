//
//  WebViewReadyChecker.swift
//  Mindbox
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Polls the page for the JS bridge instead of deciding on a single didFinish-time probe:
/// module scripts can finish evaluating a beat after the navigation's load event (reused
/// prewarmed WebView, slow devices), so one early `false` must not fail a healthy in-app.
final class WebViewReadyChecker {
    typealias Evaluate = (_ script: String, _ completion: @escaping (Result<Any?, Error>) -> Void) -> Void
    typealias Schedule = (_ delay: TimeInterval, _ work: @escaping () -> Void) -> Void

    static let maxAttempts = 8
    static let retryDelay: TimeInterval = 0.15

    private let evaluate: Evaluate
    private let schedule: Schedule
    private var isCancelled = false

    init(evaluate: @escaping Evaluate,
         schedule: @escaping Schedule = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }) {
        self.evaluate = evaluate
        self.schedule = schedule
    }

    func run(onReady: @escaping () -> Void, onGiveUp: @escaping (_ lastFailure: String) -> Void) {
        attempt(1, onReady: onReady, onGiveUp: onGiveUp)
    }

    /// Abandons the poll without calling either completion — the caller's new navigation
    /// (or teardown) owns readiness from here.
    func cancel() {
        isCancelled = true
    }

    private func attempt(_ number: Int, onReady: @escaping () -> Void, onGiveUp: @escaping (String) -> Void) {
        guard !isCancelled else { return }
        evaluate(Constants.WebViewBridgeJS.bridgeFunctionReadyCheck) { [weak self] result in
            guard let self, !self.isCancelled else { return }

            let failure: String
            switch result {
            case .success(let anyValue) where (anyValue as? String) == Constants.WebViewBridgeJS.bridgeReady:
                onReady()
                return
            case .success(let anyValue):
                failure = Self.failureDescription(for: anyValue)
            case .failure(let error):
                // Transient during navigation churn (a page mid-teardown rejects
                // evaluation) — retried on the same budget as a not-ready status.
                failure = "evaluateJavaScript error: \(error.localizedDescription)"
            }

            guard number < Self.maxAttempts else {
                onGiveUp(failure)
                return
            }
            self.schedule(Self.retryDelay) { [weak self] in
                self?.attempt(number + 1, onReady: onReady, onGiveUp: onGiveUp)
            }
        }
    }

    private static func failureDescription(for value: Any?) -> String {
        switch value as? String {
        case Constants.WebViewBridgeJS.bridgeNoNativeHandler:
            return "no-native-bridge: window.webkit.messageHandlers.\(Constants.WebViewBridgeJS.handlerName).postMessage is missing"
        case Constants.WebViewBridgeJS.bridgeNoPageHandlers:
            return "no-handlers: window.bridgeMessagesHandlers.emit is missing"
        default:
            return "unexpected ready check result: \(String(describing: value))"
        }
    }
}
