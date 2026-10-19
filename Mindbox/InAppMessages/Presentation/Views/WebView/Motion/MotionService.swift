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

enum MotionGesture: String, CaseIterable {
    case shake
    case flip
}

enum DevicePosition: String, CaseIterable {
    case faceUp
    case faceDown
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
}

struct MotionStartResult {
    let started: Set<MotionGesture>
    let unavailable: Set<MotionGesture>

    var allUnavailable: Bool { started.isEmpty && !unavailable.isEmpty }
}

protocol MotionServiceProtocol: AnyObject {
    var onGestureDetected: ((MotionGesture, [String: Any]) -> Void)? { get set }

    @discardableResult
    func startMonitoring(gestures: Set<MotionGesture>) -> MotionStartResult

    func stopMonitoring()

    func handleSystemShake()
}

final class MotionService: MotionServiceProtocol {

    // MARK: - Constants

    private enum Constants {
        static let sampleInterval: TimeInterval = 0.2

        static let enterThreshold: Double = 0.8

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
        guard !activeGestures.isEmpty else { return }
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

    func resolvePosition(gravity: CMAcceleration, current: DevicePosition?) -> DevicePosition? {
        let axes: [(value: Double, negative: DevicePosition, positive: DevicePosition)] = [
            (gravity.z, .faceUp, .faceDown),
            (gravity.y, .portrait, .portraitUpsideDown),
            (gravity.x, .landscapeLeft, .landscapeRight)
        ]

        if let current {
            for axis in axes {
                let position = axis.value > 0 ? axis.positive : axis.negative
                if position == current && abs(axis.value) > Constants.exitThreshold {
                    return current
                }
            }
        }

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
