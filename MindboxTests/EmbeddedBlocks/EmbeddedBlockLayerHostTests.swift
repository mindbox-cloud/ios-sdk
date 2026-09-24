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
        spy.isDeferred = true
        let host = EmbeddedBlockLayerHost(container: container, animation: spy.animation)
        let first = UIView()
        let second = UIView()

        host.show(first)
        host.show(second, animated: true)

        // Both are on screen while the fade runs, the new one on top; its model alpha is already 1.
        #expect(container.subviews == [first, second])
        #expect(second.alpha == 1)
        #expect(spy.runs == [Constants.EmbeddedBlock.revealAnimationDuration])

        spy.finish()

        #expect(first.superview == nil)
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
