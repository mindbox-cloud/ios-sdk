//
//  WebViewLoadingTracker.swift
//  Mindbox
//
//  Created by Mindbox on 13.04.2026.
//

import Foundation
import MindboxLogger

/// Tracks and logs timing for every stage of the WebView loading pipeline.
///
/// All logs share the `[WV Perf]` prefix for easy filtering.
///
/// **Per-flow tracking** (keyed by trackerId = shortId + flow type):
/// ```
/// let tid = WebViewLoadingTracker.makeId(inAppId: id, flow: "cold")
/// WebViewLoadingTracker.begin(id: tid, stage: "cold_start")
/// WebViewLoadingTracker.checkpoint(id: tid, stage: "navigation_finished")
/// WebViewLoadingTracker.complete(id: tid, stage: "window_shown")
/// ```
///
/// **One-shot logging** (preloader downloads, no inAppId yet):
/// ```
/// WebViewLoadingTracker.log("html_downloaded | 120ms — https://...")
/// ```
final class WebViewLoadingTracker {

    private static var trackers: [String: WebViewLoadingTracker] = [:]
    private static let lock = NSLock()

    private let origin: CFAbsoluteTime
    private var lastCheckpoint: CFAbsoluteTime
    private let id: String

    private init(id: String) {
        let now = CFAbsoluteTimeGetCurrent()
        self.origin = now
        self.lastCheckpoint = now
        self.id = id
    }

    // MARK: - ID Helper

    /// Creates a human-readable tracker ID: `"037c6f8f cold"` or `"037c6f8f prerender"`.
    static func makeId(inAppId: String, flow: String) -> String {
        "\(inAppId.prefix(8)) \(flow)"
    }

    // MARK: - Static Registry

    @discardableResult
    static func begin(id: String, stage: String = "started") -> WebViewLoadingTracker {
        let tracker = WebViewLoadingTracker(id: id)
        lock.lock()
        trackers[id] = tracker
        lock.unlock()
        tracker.log(stage)
        return tracker
    }

    static func checkpoint(id: String?, stage: String) {
        guard let id else { return }
        lock.lock()
        let tracker = trackers[id]
        lock.unlock()
        tracker?.log(stage)
    }

    static func complete(id: String?, stage: String = "complete") {
        guard let id else { return }
        lock.lock()
        let tracker = trackers.removeValue(forKey: id)
        lock.unlock()
        tracker?.log(stage)
    }

    // MARK: - Instance

    private func log(_ stage: String) {
        let now = CFAbsoluteTimeGetCurrent()
        let stepMs = Int((now - lastCheckpoint) * 1000)
        let totalMs = Int((now - origin) * 1000)
        lastCheckpoint = now

        Logger.common(
            message: "[WV Perf] [\(id)] \(stage) | +\(stepMs)ms | total: \(totalMs)ms",
            category: .webViewInAppMessages
        )
    }

    // MARK: - One-shot (no inAppId context)

    static func log(_ message: String) {
        Logger.common(
            message: "[WV Perf] \(message)",
            category: .webViewInAppMessages
        )
    }
}
