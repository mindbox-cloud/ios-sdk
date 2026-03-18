//
//  HapticService.swift
//  Mindbox
//
//  Created by Sergei Semko on 3/16/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import CoreHaptics
import MindboxLogger

protocol HapticServiceProtocol {
    func prepare()
    func stopPattern()
    func handle(message: BridgeMessage)
}

final class HapticService: HapticServiceProtocol {

    // MARK: - Generators

    private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    /// Retains the `CHHapticEngine` while a pattern is playing (engine deallocates → playback stops).
    /// Typed as `AnyObject` because `CHHapticEngine` requires iOS 13+ and the class must support iOS 12.
    private var activeEngineStorage: AnyObject?

    // MARK: - Stop

    func stopPattern() {
        if #available(iOS 13.0, *) {
            (activeEngineStorage as? CHHapticEngine)?.stop()
        }
        activeEngineStorage = nil
    }

    // MARK: - Prepare

    func prepare() {
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        var styles: [UIImpactFeedbackGenerator.FeedbackStyle] = [.light, .medium, .heavy]
        if #available(iOS 13.0, *) {
            styles.append(contentsOf: [.soft, .rigid])
        }
        for style in styles {
            impactGenerator(for: style).prepare()
        }
    }

    // MARK: - Handle bridge message

    func handle(message: BridgeMessage) {
        let request = HapticRequestParser.parse(from: message)

        guard HapticRequestValidator.isValid(request) else { return }

        switch request {
        case .selection:
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()

        case .impact(let style):
            let gen = impactGenerator(for: style.feedbackStyle)
            gen.impactOccurred()
            gen.prepare()

        case .notification(let style):
            notificationGenerator.notificationOccurred(style.feedbackType)
            notificationGenerator.prepare()

        case .pattern(let events):
            if #available(iOS 13.0, *) {
                playPattern(events: events)
            }
        }
    }

    // MARK: - Impact generator cache

    private func impactGenerator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let cached = impactGenerators[style] {
            return cached
        }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        impactGenerators[style] = generator
        return generator
    }

    // MARK: - Core Haptics pattern

    @available(iOS 13.0, *)
    private func playPattern(events: [HapticPatternEvent]) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            stopPattern()

            let engine = try CHHapticEngine()
            try engine.start()
            activeEngineStorage = engine

            let hapticEvents = events.map { event -> CHHapticEvent in
                let time = event.time / 1000.0
                let duration = event.duration / 1000.0
                let intensity = Float(event.intensity)
                let sharpness = Float(event.sharpness)

                let params = [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ]

                if duration > 0 {
                    return CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: params,
                        relativeTime: time,
                        duration: duration
                    )
                } else {
                    return CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: params,
                        relativeTime: time
                    )
                }
            }

            let pattern = try CHHapticPattern(events: hapticEvents, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)

            let totalDuration = events.map { $0.time / 1000.0 + max($0.duration / 1000.0, 0.05) }.max() ?? 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.5) { [weak self] in
                self?.stopPattern()
            }
        } catch {
            Logger.common(
                message: "[WebView] Core Haptics error: \(error)",
                category: .webViewInAppMessages
            )
        }
    }
}
