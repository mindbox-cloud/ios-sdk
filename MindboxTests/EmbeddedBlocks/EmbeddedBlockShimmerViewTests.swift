//
//  EmbeddedBlockShimmerViewTests.swift
//  MindboxTests
//
//  Created by vailence on 07.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@testable import Mindbox

/// The stock placeholder against its design: a mask of one tint whose opacity alone changes, sized
/// in fractions of the block, sweeping once per cycle, and in step with every other shimmer around.
@Suite("Embedded block shimmer", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockShimmerViewTests {

    private typealias Design = EmbeddedBlockShimmerView.Design

    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    /// Private: the foreground notification posted here must not reach the SDK's own observers or
    /// the tests running alongside.
    private let notificationCenter = NotificationCenter()

    private func makeShimmer() -> EmbeddedBlockShimmerView {
        EmbeddedBlockShimmerView(frame: CGRect(x: 0, y: 0, width: 320, height: 120),
                                 notificationCenter: notificationCenter)
    }

    private func enterForeground() {
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func sweep(of shimmer: EmbeddedBlockShimmerView) -> CAKeyframeAnimation? {
        shimmer.gradientLayer.animation(forKey: EmbeddedBlockShimmerView.animationKey) as? CAKeyframeAnimation
    }

    private struct RGBA: Equatable {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        init(_ color: CGColor) {
            UIColor(cgColor: color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }
    }

    private func isClose(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.001
    }

    // MARK: - Color

    @Test("Light appearance is one near-black tint whose opacity dips in the highlight")
    func lightAppearanceIsOneTintWithADippingHighlight() {
        let colors = Design.colors(isDark: false).map(RGBA.init)

        #expect(colors.count == 5)
        #expect(colors.allSatisfy { isClose($0.red, 0x28 / 255.0) && isClose($0.green, 0x2A / 255.0) && isClose($0.blue, 0x2F / 255.0) })
        #expect(zip(colors.map(\.alpha), [0.08, 0.08, 0.04, 0.08, 0.08]).allSatisfy { isClose($0, $1) })
    }

    @Test("Dark appearance is one white tint whose opacity peaks in the highlight")
    func darkAppearanceIsOneTintWithAPeakingHighlight() {
        let colors = Design.colors(isDark: true).map(RGBA.init)

        #expect(colors.count == 5)
        #expect(colors.allSatisfy { isClose($0.red, 1) && isClose($0.green, 1) && isClose($0.blue, 1) })
        #expect(zip(colors.map(\.alpha), [0.08, 0.08, 0.16, 0.08, 0.08]).allSatisfy { isClose($0, $1) })
    }

    @Test("The view paints nothing under the tint: it is a mask over the host's background")
    func viewPaintsNothingUnderTheTint() {
        let shimmer = makeShimmer()

        #expect(shimmer.backgroundColor == .clear)
        #expect(shimmer.gradientLayer.backgroundColor == nil)
        #expect(shimmer.isUserInteractionEnabled == false)
        #expect(shimmer.gradientLayer.colors?.count == 5)
    }

    @Test("The gradient runs horizontally across the whole view")
    func gradientRunsHorizontallyAcrossTheView() {
        let shimmer = makeShimmer()

        shimmer.layoutIfNeeded()

        #expect(shimmer.gradientLayer.frame == shimmer.bounds)
        #expect(shimmer.gradientLayer.startPoint == CGPoint(x: 0, y: 0.5))
        #expect(shimmer.gradientLayer.endPoint == CGPoint(x: 1, y: 0.5))
    }

    // MARK: - Geometry

    @Test("Stops follow the gradient layer: moving it shifts every stop by the same fraction")
    func stopsFollowTheGradientLayer() {
        let atZero = Design.locations(forLayerAt: 0)
        let shifted = Design.locations(forLayerAt: -1.5)

        #expect(zip(atZero.map { $0 / Design.layerWidth }, Design.stops).allSatisfy { isClose($0, $1) })
        #expect(zip(atZero, shifted).allSatisfy { isClose($0 - $1, 1.5) })
    }

    @Test("At both rest positions the ramp lies outside the block, which shows a flat tint")
    func rampIsHiddenAtBothRestPositions() {
        // The ramp is the three middle stops; the outer two are flat and may be anywhere.
        let rampAtStart = Design.startLocations[1...3]
        let rampAtEnd = Design.endLocations[1...3]

        #expect(rampAtStart.allSatisfy { $0 < 0 }, "before the sweep the ramp waits off the leading edge")
        #expect(rampAtEnd.allSatisfy { $0 > 1 }, "after the sweep the ramp has left past the trailing edge")
        // And the flat outer stops still cover the block from both sides at either rest.
        #expect(Design.startLocations.first! < 0 && Design.startLocations.last! > 1)
        #expect(Design.endLocations.first! < 0 && Design.endLocations.last! > 1)
    }

    @Test("A fresh shimmer rests at the start position")
    func freshShimmerRestsAtTheStartPosition() {
        let shimmer = makeShimmer()

        let locations = shimmer.gradientLayer.locations?.map { CGFloat($0.doubleValue) } ?? []

        #expect(zip(locations, Design.startLocations).allSatisfy { isClose($0, $1) })
        #expect(locations.count == Design.startLocations.count)
    }

    // MARK: - Cycle

    @Test("One cycle: rest 0.6 s, sweep 1 s with ease-in, rest 0.6 s, jump back")
    func cycleMatchesTheDesign() throws {
        let animation = EmbeddedBlockShimmerView.makeSweep(beginningAt: 1)

        #expect(animation.keyPath == "locations")
        #expect(isClose(CGFloat(animation.duration), 2.2))
        #expect(animation.repeatCount == .infinity)

        let keyTimes = try #require(animation.keyTimes).map { CGFloat($0.doubleValue) }
        #expect(keyTimes.count == 4)
        #expect(isClose(keyTimes[0], 0))
        #expect(isClose(keyTimes[1], 0.6 / 2.2))
        #expect(isClose(keyTimes[2], 1.6 / 2.2))
        #expect(isClose(keyTimes[3], 1))

        let values = try #require(animation.values as? [[NSNumber]]).map { $0.map { CGFloat($0.doubleValue) } }
        #expect(values.count == 4)
        #expect(values[0] == values[1], "the first rest holds the start position")
        #expect(values[2] == values[3], "the second rest holds the end position")
        #expect(zip(values[0], Design.startLocations).allSatisfy { isClose($0, $1) })
        #expect(zip(values[2], Design.endLocations).allSatisfy { isClose($0, $1) })

        let timing = try #require(animation.timingFunctions)
        #expect(timing.count == 3)
        var sweepControlPoint: [Float] = [0, 0]
        timing[1].getControlPoint(at: 1, values: &sweepControlPoint)
        #expect(abs(sweepControlPoint[0] - 0.42) < 0.001 && abs(sweepControlPoint[1]) < 0.001, "the sweep itself eases in")
    }

    @Test("Starts sweeping in a window and stops when it leaves")
    func sweepsOnlyInAWindow() {
        let shimmer = makeShimmer()

        #expect(sweep(of: shimmer) == nil)

        window.addSubview(shimmer)
        #expect(sweep(of: shimmer) != nil)

        shimmer.removeFromSuperview()
        #expect(sweep(of: shimmer) == nil)
    }

    @Test("A start while already sweeping never stacks a second sweep")
    func repeatedStartKeepsOneSweep() {
        let shimmer = makeShimmer()
        window.addSubview(shimmer)

        // The foreground notification is a second start request on a shimmer already on screen.
        enterForeground()
        enterForeground()

        #expect(shimmer.gradientLayer.animationKeys() == [EmbeddedBlockShimmerView.animationKey])
    }

    @Test("Returning to the foreground restarts a sweep the system has dropped")
    func foregroundRestartsADroppedSweep() {
        let shimmer = makeShimmer()
        window.addSubview(shimmer)
        // The system removes infinite animations while the app is in the background.
        shimmer.gradientLayer.removeAllAnimations()
        #expect(sweep(of: shimmer) == nil)

        enterForeground()

        #expect(sweep(of: shimmer) != nil)
    }

    @Test("Returning to the foreground does not start a shimmer that is off screen")
    func foregroundLeavesAnOffScreenShimmerAlone() {
        let shimmer = makeShimmer()

        enterForeground()

        #expect(sweep(of: shimmer) == nil)
    }

    // MARK: - Shared beat

    @Test("Every shimmer counts its cycle from the same instant, whenever it appears")
    func shimmersShareOneBeat() throws {
        let first = makeShimmer()
        let second = makeShimmer()
        window.addSubview(first)
        let firstSweep = try #require(sweep(of: first))

        // The second one comes later, mid-cycle of the first.
        window.addSubview(second)
        let secondSweep = try #require(sweep(of: second))

        #expect(firstSweep.beginTime == secondSweep.beginTime)
        #expect(firstSweep.beginTime == first.gradientLayer.convertTime(EmbeddedBlockShimmerView.beatEpoch, from: nil))
    }

    @Test("The shared beat began in the past, so a new sweep joins the cycle in progress")
    func sharedBeatBeganInThePast() {
        #expect(EmbeddedBlockShimmerView.beatEpoch > 0)
        #expect(EmbeddedBlockShimmerView.beatEpoch <= CACurrentMediaTime())
    }

    @Test("Re-entering a window keeps the beat rather than starting a cycle of its own")
    func reEnteringAWindowKeepsTheBeat() throws {
        let shimmer = makeShimmer()
        window.addSubview(shimmer)
        let before = try #require(sweep(of: shimmer)).beginTime

        shimmer.removeFromSuperview()
        window.addSubview(shimmer)
        let after = try #require(sweep(of: shimmer)).beginTime

        #expect(before == after)
    }
}
