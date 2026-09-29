//
//  EmbeddedBlockLayerHostTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@_spi(Internal) @testable import Mindbox

/// The layer host has one promise: the container holds exactly one view, stretched to its edges. The
/// block's layers are mutually exclusive, so showing a new one means removing the previous one.
@Suite("Embedded block layer host", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockLayerHostTests {

    @Test("Shown view fills the container")
    func shownViewFillsTheContainer() {
        let container = UIView()
        let host = EmbeddedBlockLayerHost(container: container)
        let layer = UIView()

        host.show(layer)

        #expect(layer.superview === container)
        #expect(layer.translatesAutoresizingMaskIntoConstraints == false)
        // Four edges: the layer always fills the container it was given.
        #expect(container.constraints.count == 4)
    }

    @Test("Showing another view replaces the first")
    func showingAnotherViewReplacesTheFirst() {
        let container = UIView()
        let host = EmbeddedBlockLayerHost(container: container)
        let first = UIView()
        let second = UIView()

        host.show(first)
        host.show(second)

        #expect(first.superview == nil)
        #expect(second.superview === container)
        #expect(container.subviews.count == 1)
        #expect(container.constraints.count == 4)
    }

    @Test("Showing nothing detaches the current view")
    func showingNothingDetachesTheCurrentView() {
        let container = UIView()
        let host = EmbeddedBlockLayerHost(container: container)
        let layer = UIView()

        host.show(layer)
        host.show(nil)

        #expect(layer.superview == nil)
        #expect(container.subviews.isEmpty)
        #expect(container.constraints.isEmpty)
    }

    /// A collapsed block stays collapsed and keeps receiving `show(nil)` on every state change:
    /// there is nothing to remove, and the host must not touch the container.
    @Test("Showing nothing when nothing is shown changes nothing")
    func showingNothingOnEmptyHostChangesNothing() {
        let container = UIView()
        let host = EmbeddedBlockLayerHost(container: container)

        host.show(nil)
        host.show(nil)

        #expect(container.subviews.isEmpty)
        #expect(container.constraints.isEmpty)
    }

    /// The container calls `show` on every state change, and some of those calls come with the same
    /// view. There is no reason to rebuild its constraints — they would simply keep piling up.
    @Test("Showing the same view again changes nothing")
    func showingTheSameViewAgainChangesNothing() {
        let container = UIView()
        let host = EmbeddedBlockLayerHost(container: container)
        let layer = UIView()

        host.show(layer)
        host.show(layer)
        host.show(layer)

        #expect(container.subviews.count == 1)
        #expect(container.constraints.count == 4)
    }

    /// The view to remove is the one that is actually attached: if it was detached from outside,
    /// showing it again must put it back rather than decide it is already there.
    @Test("A view detached from outside is attached again")
    func viewDetachedFromOutsideIsAttachedAgain() {
        let container = UIView()
        let host = EmbeddedBlockLayerHost(container: container)
        let layer = UIView()

        host.show(layer)
        layer.removeFromSuperview()
        host.show(layer)

        #expect(layer.superview === container)
        #expect(container.constraints.count == 4)
    }

    // MARK: - The fade

    @Test("An animated show fades the new view in over the previous one, which leaves when the fade ends")
    func animatedShowFadesInAndDropsThePreviousWhenTheFadeEnds() {
        let container = UIView()
        let spy = EmbeddedBlockRevealAnimationSpy()
        spy.holdsAnimations = true
        spy.isDeferred = true
        let host = EmbeddedBlockLayerHost(container: container, animation: spy.animation)
        let first = UIView()
        let second = UIView()

        host.show(first)
        host.show(second, animated: true)

        // Both are on screen while the fade runs, the new one on top. Before the animation starts
        // the new one is invisible and the previous one untouched: the fade begins from here.
        #expect(container.subviews == [first, second])
        #expect(second.alpha == 0)
        #expect(first.alpha == 1)
        #expect(spy.runs == [Constants.EmbeddedBlock.revealAnimationDuration])

        // The animations set the model values the way UIKit does: the new one at 1, the previous one
        // at 0 — a cross-fade, not a fade over an opaque layer.
        spy.applyAnimations()

        #expect(second.alpha == 1)
        #expect(first.alpha == 0)

        spy.finish()

        #expect(first.superview == nil)
        // Ready to be shown again on the next load.
        #expect(first.alpha == 1)
        #expect(container.subviews == [second])
        #expect(container.constraints.count == 4)
    }

    @Test("An animated show with nothing to replace fades the view in alone")
    func animatedShowWithoutAPreviousViewFadesInAlone() {
        let container = UIView()
        let spy = EmbeddedBlockRevealAnimationSpy()
        let host = EmbeddedBlockLayerHost(container: container, animation: spy.animation)
        let layer = UIView()

        host.show(layer, animated: true)

        #expect(container.subviews == [layer])
        #expect(spy.runs.count == 1)
        #expect(container.constraints.count == 4)
    }

    @Test("A show interrupting a fade removes the fading view at once")
    func showInterruptingAFadeRemovesTheFadingViewAtOnce() {
        let container = UIView()
        let spy = EmbeddedBlockRevealAnimationSpy()
        spy.isDeferred = true
        let host = EmbeddedBlockLayerHost(container: container, animation: spy.animation)
        let first = UIView()
        let second = UIView()
        let third = UIView()

        host.show(first)
        host.show(second, animated: true)
        host.show(third)
        spy.finish()

        #expect(first.superview == nil)
        // Dropped mid-fade, yet ready to be shown again on the next load.
        #expect(first.alpha == 1)
        #expect(second.superview == nil)
        #expect(container.subviews == [third])
        #expect(container.constraints.count == 4)
    }

    @Test("Showing nothing during a fade removes both views")
    func showingNothingDuringAFadeRemovesBothViews() {
        let container = UIView()
        let spy = EmbeddedBlockRevealAnimationSpy()
        spy.isDeferred = true
        let host = EmbeddedBlockLayerHost(container: container, animation: spy.animation)
        let first = UIView()
        let second = UIView()

        host.show(first)
        host.show(second, animated: true)
        host.show(nil)
        spy.finish()

        #expect(container.subviews.isEmpty)
        #expect(container.constraints.isEmpty)
    }

    /// A host's own placeholder may be translucent by design: the fade must not hand it back opaque.
    @Test("The fading view leaves with the alpha it came with", arguments: [true, false])
    func fadingViewLeavesWithItsOwnAlpha(fadeEnds: Bool) {
        let container = UIView()
        let spy = EmbeddedBlockRevealAnimationSpy()
        spy.isDeferred = true
        let host = EmbeddedBlockLayerHost(container: container, animation: spy.animation)
        let first = UIView()
        first.alpha = 0.5
        let second = UIView()

        host.show(first)
        host.show(second, animated: true)
        if fadeEnds {
            spy.finish()
        } else {
            host.show(UIView())
        }

        #expect(first.superview == nil)
        #expect(first.alpha == 0.5)
    }

    /// The block can be torn down before its fade ends. The view it was fading out belongs to the
    /// host, who may show it elsewhere: it must not stay transparent.
    @Test("A host gone mid-fade still gives the fading view its alpha back")
    func hostGoneMidFadeRestoresTheAlpha() {
        let container = UIView()
        let spy = EmbeddedBlockRevealAnimationSpy()
        spy.isDeferred = true
        var host: EmbeddedBlockLayerHost? = EmbeddedBlockLayerHost(container: container, animation: spy.animation)
        let first = UIView()
        first.alpha = 0.5
        let second = UIView()

        host?.show(first)
        host?.show(second, animated: true)
        #expect(first.alpha == 0)
        host = nil
        spy.finish()

        #expect(first.alpha == 0.5)
    }

    /// A late completion of a fade that was already cut short must not remove the view that replaced it.
    @Test("A fade cut short by another fade does not remove the newer view when it ends")
    func cutShortFadeDoesNotRemoveTheNewerView() {
        let container = UIView()
        let spy = EmbeddedBlockRevealAnimationSpy()
        spy.isDeferred = true
        let host = EmbeddedBlockLayerHost(container: container, animation: spy.animation)
        let first = UIView()
        let second = UIView()
        let third = UIView()

        host.show(first)
        host.show(second, animated: true)
        host.show(third, animated: true)
        spy.finish()

        #expect(container.subviews == [third])
        #expect(container.constraints.count == 4)
    }
}
