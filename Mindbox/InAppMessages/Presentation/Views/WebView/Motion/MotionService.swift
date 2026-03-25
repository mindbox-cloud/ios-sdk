//
//  MotionService.swift
//  Mindbox
//
//  Created by Sergei Semko on 3/20/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import CoreMotion
import MindboxLogger

/// Motion gestures that can be monitored via the bridge `motion.start` action.
///
/// - `shake`: Device was shaken. Detected via system `UIResponder.motionEnded`.
/// - `flip`: Device changed orientation (one of 6 faces). Detected via `CMMotionManager` gravity.
enum MotionGesture: String, CaseIterable {
    case shake
    case flip
}

/// Device orientation based on dominant gravity axis (6 faces of a cube).
///
/// Each face corresponds to one axis exceeding the gravity threshold:
///
/// | Position | Axis | Condition |
/// |---|---|---|
/// | `faceUp` | Z | `gravity.z < -0.8` |
/// | `faceDown` | Z | `gravity.z > +0.8` |
/// | `portrait` | Y | `gravity.y < -0.8` |
/// | `portraitUpsideDown` | Y | `gravity.y > +0.8` |
/// | `landscapeLeft` | X | `gravity.x < -0.8` |
/// | `landscapeRight` | X | `gravity.x > +0.8` |
enum DevicePosition: String, CaseIterable {
    /// Lying screen up (e.g. on a table). `gravity.z < -threshold`.
    case faceUp
    /// Lying screen down (flipped on a table). `gravity.z > +threshold`.
    case faceDown
    /// Upright, normal orientation (held in hand). `gravity.y < -threshold`.
    case portrait
    /// Upright, flipped upside down. `gravity.y > +threshold`.
    case portraitUpsideDown
    /// Rotated left (landscape, volume buttons on top). `gravity.x < -threshold`.
    case landscapeLeft
    /// Rotated right (landscape, volume buttons on bottom). `gravity.x > +threshold`.
    case landscapeRight
}

/// Result of ``MotionServiceProtocol/startMonitoring(gestures:)``.
///
/// Reports which gestures were successfully started and which were unavailable
/// (e.g. flip on a device without gyroscope).
struct MotionStartResult {
    /// Gestures that were successfully started.
    let started: Set<MotionGesture>
    /// Gestures that could not be started (sensor unavailable).
    let unavailable: Set<MotionGesture>

    /// `true` if no gestures could be started at all.
    var allUnavailable: Bool { started.isEmpty && !unavailable.isEmpty }
}

/// Monitors device motion gestures (shake, flip) and reports events via callback.
///
/// - Shake is detected via system `UIResponder.motionEnded(.motionShake)`.
///   The host app's `applicationSupportsShakeToEdit` is temporarily disabled while shake is active.
/// - Flip is detected via `CMMotionManager.deviceMotion` gravity vector across 3 axes,
///   using hysteresis (enter 0.8g / exit 0.6g) to prevent flickering at axis boundaries.
/// - Sensors auto-suspend on app background and resume on foreground.
protocol MotionServiceProtocol: AnyObject {
    /// Called on main thread when a gesture is detected.
    /// - Parameters:
    ///   - gesture: The detected gesture type.
    ///   - data: Gesture-specific payload (e.g. `["from": "portrait", "to": "faceDown"]` for flip).
    var onGestureDetected: ((MotionGesture, [String: Any]) -> Void)? { get set }

    /// Starts monitoring the specified gestures. Replaces any previous subscription.
    ///
    /// - Parameter gestures: Set of gestures to monitor.
    /// - Returns: Result indicating which gestures started and which were unavailable.
    @discardableResult
    func startMonitoring(gestures: Set<MotionGesture>) -> MotionStartResult

    /// Stops all gesture monitoring, restores system settings, and releases sensors.
    func stopMonitoring()

    /// Called by `WebViewController.motionEnded` when system detects a shake.
    func handleSystemShake()
}

final class MotionService: MotionServiceProtocol {

    // MARK: - Constants

    private enum Constants {
        /// How often deviceMotion data is sampled, in seconds.
        /// 0.2s = 5 times per second (5 Hz). Sufficient for flip detection (a flip takes ~0.5–1s).
        /// For continuous streaming (e.g. tilt games), use 1/30 or 1/60.
        static let sampleInterval: TimeInterval = 0.2

        /// Gravity magnitude required to enter a new position.
        /// Must be exceeded for the device to switch to a different face.
        static let enterThreshold: Double = 0.8

        /// Gravity magnitude below which the current position is released.
        /// The gap between enter (0.8) and exit (0.6) creates a dead zone
        /// that prevents flickering when the device is tilted between two faces (~45°).
        static let exitThreshold: Double = 0.6
    }

    // MARK: - Properties

    var onGestureDetected: ((MotionGesture, [String: Any]) -> Void)?

    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private var activeGestures = Set<MotionGesture>()
    private var suspendedGestures: Set<MotionGesture>?

    // MARK: - Flip detection

    private var currentPosition: DevicePosition?

    // MARK: - Shake-to-edit suppression

    private var savedShakeToEditSetting: Bool?

    // MARK: - Lifecycle observers

    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    deinit {
        removeLifecycleObservers()
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        if let saved = savedShakeToEditSetting {
            DispatchQueue.main.async {
                UIApplication.shared.applicationSupportsShakeToEdit = saved
            }
        }
    }

    // MARK: - Public

    @discardableResult
    func startMonitoring(gestures: Set<MotionGesture>) -> MotionStartResult {
        stopMonitoring()

        var unavailable = Set<MotionGesture>()
        if gestures.contains(.flip) && !motionManager.isDeviceMotionAvailable {
            unavailable.insert(.flip)
        }

        activeGestures = gestures.subtracting(unavailable)

        let result = MotionStartResult(started: activeGestures, unavailable: unavailable)
        guard !activeGestures.isEmpty else { return result }

        if activeGestures.contains(.shake) {
            disableShakeToEdit()
        }

        addLifecycleObservers()
        startSensors()

        Logger.common(
            message: "[WebView] Motion: monitoring started for \(activeGestures.map(\.rawValue))",
            category: .webViewInAppMessages
        )

        if !unavailable.isEmpty {
            Logger.common(
                message: "[WebView] Motion: unavailable gestures: \(unavailable.map(\.rawValue))",
                category: .webViewInAppMessages
            )
        }

        return result
    }

    func stopMonitoring() {
        removeLifecycleObservers()
        stopSensors()
        restoreShakeToEdit()
        activeGestures.removeAll()
        suspendedGestures = nil
        Logger.common(message: "[WebView] Motion: monitoring stopped", category: .webViewInAppMessages)
    }

    // MARK: - Lifecycle

    private func addLifecycleObservers() {
        removeLifecycleObservers()

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.suspend()
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resume()
        }
    }

    private func removeLifecycleObservers() {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
    }

    private func suspend() {
        guard !activeGestures.isEmpty else { return }
        suspendedGestures = activeGestures
        stopSensors()
        Logger.common(message: "[WebView] Motion: suspended (app in background)", category: .webViewInAppMessages)
    }

    private func resume() {
        guard let gestures = suspendedGestures else { return }
        suspendedGestures = nil
        activeGestures = gestures
        startSensors()
        Logger.common(message: "[WebView] Motion: resumed (app in foreground)", category: .webViewInAppMessages)
    }

    // MARK: - Shake-to-edit

    private func disableShakeToEdit() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.savedShakeToEditSetting == nil else { return }
            self.savedShakeToEditSetting = UIApplication.shared.applicationSupportsShakeToEdit
            UIApplication.shared.applicationSupportsShakeToEdit = false
        }
    }

    private func restoreShakeToEdit() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let saved = self.savedShakeToEditSetting else { return }
            UIApplication.shared.applicationSupportsShakeToEdit = saved
            self.savedShakeToEditSetting = nil
        }
    }

    // MARK: - Sensors

    private func stopSensors() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        currentPosition = nil
    }

    private func startSensors() {
        guard activeGestures.contains(.flip), motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = Constants.sampleInterval
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.processFlip(gravity: motion.gravity)
        }
    }

    // MARK: - System Shake (via UIResponder.motionEnded)

    func handleSystemShake() {
        guard activeGestures.contains(.shake) else { return }
        Logger.common(message: "[WebView] Motion: system shake detected", category: .webViewInAppMessages)
        onGestureDetected?(.shake, [:])
    }

    // MARK: - Flip (reports every position change, JS filters as needed)

    private func processFlip(gravity: CMAcceleration) {
        guard activeGestures.contains(.flip) else { return }

        let newPosition = resolvePosition(gravity: gravity, current: currentPosition)
        guard let newPosition else { return }
        guard newPosition != currentPosition else { return }

        let previous = currentPosition
        currentPosition = newPosition

        guard let from = previous else { return }

        Logger.common(
            message: "[WebView] Motion: flip detected \(from.rawValue) → \(newPosition.rawValue)",
            category: .webViewInAppMessages
        )
        DispatchQueue.main.async { [weak self] in
            self?.onGestureDetected?(.flip, ["from": from.rawValue, "to": newPosition.rawValue])
        }
    }

    /// Hysteresis-based position detection.
    /// Requires `enterThreshold` to switch to a new position,
    /// but keeps the current position until gravity drops below `exitThreshold`.
    /// This prevents flickering at axis boundaries without needing time-based cooldown.
    func resolvePosition(gravity: CMAcceleration, current: DevicePosition?) -> DevicePosition? {
        let axes: [(value: Double, negative: DevicePosition, positive: DevicePosition)] = [
            (gravity.z, .faceUp, .faceDown),
            (gravity.y, .portrait, .portraitUpsideDown),
            (gravity.x, .landscapeLeft, .landscapeRight)
        ]

        // Check if current position still holds (above exit threshold)
        if let current {
            for axis in axes {
                let position = axis.value > 0 ? axis.positive : axis.negative
                if position == current && abs(axis.value) > Constants.exitThreshold {
                    return current
                }
            }
        }

        // Current position lost — find new dominant position (above enter threshold)
        var best: DevicePosition?
        var bestMagnitude: Double = Constants.enterThreshold

        for axis in axes {
            let magnitude = abs(axis.value)
            if magnitude > bestMagnitude {
                bestMagnitude = magnitude
                best = axis.value > 0 ? axis.positive : axis.negative
            }
        }

        return best
    }
}
