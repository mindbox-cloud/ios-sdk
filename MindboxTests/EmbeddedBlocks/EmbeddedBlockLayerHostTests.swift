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

    @Test("Showing nothing when nothing is shown changes nothing")
    func showingNothingOnEmptyHostChangesNothing() {
        let container = UIView()
        let host = EmbeddedBlockLayerHost(container: container)

        host.show(nil)
        host.show(nil)

        #expect(container.subviews.isEmpty)
        #expect(container.constraints.isEmpty)
    }

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

        #expect(container.subviews == [first, second])
        #expect(second.alpha == 0)
        #expect(first.alpha == 1)
        #expect(spy.runs == [Constants.EmbeddedBlock.revealAnimationDuration])

        spy.applyAnimations()

        #expect(second.alpha == 1)
        #expect(first.alpha == 0)

        spy.finish()

        #expect(first.superview == nil)
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

    // MARK: - The cover

    @Test("A placeholder covering the content lies on top of it, with the content kept in place, unseen and hidden from accessibility")
    func coverKeepsTheContentInPlaceUnderThePlaceholder() {
        let container = UIView()
        var covered: UIView?
        let host = EmbeddedBlockLayerHost(container: container, coveredContent: { covered })
        let content = UIView()
        let placeholder = UIView()

        host.show(content)
        covered = content
        host.show(placeholder)

        #expect(container.subviews == [content, placeholder])
        #expect(content.alpha == 0)
        #expect(content.accessibilityElementsHidden)
        #expect(container.constraints.count == 8)
    }

    @Test("Covering the content takes the keyboard focus from it")
    func coverTakesTheKeyboardFocusFromTheContent() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        window.makeKeyAndVisible()
        let container = UIView(frame: window.bounds)
        window.addSubview(container)
        var covered: UIView?
        let host = EmbeddedBlockLayerHost(container: container, coveredContent: { covered })
        let content = UIView()
        let field = UITextField()
        content.addSubview(field)
        host.show(content)
        try #require(field.becomeFirstResponder())

        covered = content
        host.show(UIView())

        #expect(!field.isFirstResponder)
    }

    @Test("Another placeholder over the covered content replaces the cover and leaves the content as it is")
    func newPlaceholderReplacesTheCover() {
        let container = UIView()
        let content = UIView()
        let host = EmbeddedBlockLayerHost(container: container, coveredContent: { content })
        let first = UIView()
        first.alpha = 0.5
        let second = UIView()

        host.show(first)
        host.show(second)

        #expect(container.subviews == [content, second])
        #expect(first.superview == nil)
        #expect(first.alpha == 0.5)
        #expect(content.alpha == 0)
    }

    @Test("Lifting the cover fades the placeholder out over the content, which never leaves the container")
    func liftingTheCoverFadesThePlaceholderOutOverTheContent() {
        let container = UIView()
        let spy = EmbeddedBlockRevealAnimationSpy()
        spy.holdsAnimations = true
        spy.isDeferred = true
        var covered: UIView?
        let host = EmbeddedBlockLayerHost(container: container, animation: spy.animation, coveredContent: { covered })
        let content = UIView()
        let placeholder = UIView()
        host.show(content)
        covered = content
        host.show(placeholder)

        covered = nil
        host.show(content, animated: true)

        #expect(container.subviews == [content, placeholder])
        #expect(!content.accessibilityElementsHidden)

        spy.applyAnimations()

        #expect(content.alpha == 1)
        #expect(placeholder.alpha == 0)

        spy.finish()

        #expect(container.subviews == [content])
        #expect(placeholder.alpha == 1)
        #expect(container.constraints.count == 4)
    }

    @Test("Lifting the cover without the fade drops the placeholder at once")
    func liftingTheCoverWithoutTheFadeDropsThePlaceholderAtOnce() {
        let container = UIView()
        var covered: UIView?
        let host = EmbeddedBlockLayerHost(container: container, coveredContent: { covered })
        let content = UIView()
        let placeholder = UIView()
        host.show(content)
        covered = content
        host.show(placeholder)

        covered = nil
        host.show(content)

        #expect(container.subviews == [content])
        #expect(content.alpha == 1)
        #expect(!content.accessibilityElementsHidden)
    }

    @Test("Showing nothing or another view over the covered content drops both and gives the content back its look", arguments: [true, false])
    func showingSomethingElseOverTheCoverDropsBoth(showsAnotherView: Bool) {
        let container = UIView()
        var covered: UIView?
        let host = EmbeddedBlockLayerHost(container: container, coveredContent: { covered })
        let content = UIView()
        let placeholder = UIView()
        let other = UIView()
        host.show(content)
        covered = content
        host.show(placeholder)

        covered = nil
        host.show(showsAnotherView ? other : nil)

        #expect(container.subviews == (showsAnotherView ? [other] : []))
        #expect(content.superview == nil)
        #expect(placeholder.superview == nil)
        #expect(content.alpha == 1)
        #expect(!content.accessibilityElementsHidden)
    }
}
