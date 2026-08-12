//
//  EmbeddedBlockLayerHostTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@testable import Mindbox

/// У хоста слоёв одно обещание: в контейнере ровно одна вью и она растянута по его краям. Слои блока
/// взаимоисключающие, поэтому показать новый значит снять прежний.
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
        // Четыре края: слой всегда заполняет контейнер, который ему дали.
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

    /// Схлопнутый блок остаётся схлопнутым и продолжает получать `show(nil)` на каждую смену
    /// состояния: снимать нечего, и трогать контейнер хост не должен.
    @Test("Showing nothing when nothing is shown changes nothing")
    func showingNothingOnEmptyHostChangesNothing() {
        let container = UIView()
        let host = EmbeddedBlockLayerHost(container: container)

        host.show(nil)
        host.show(nil)

        #expect(container.subviews.isEmpty)
        #expect(container.constraints.isEmpty)
    }

    /// Контейнер зовёт `show` на каждую смену состояния, и часть этих вызовов приходит с той же вью.
    /// Пересобирать под неё констрейнты незачем — их бы просто становилось больше.
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

    /// Снимать надо ту вью, что действительно висит: если её убрали снаружи, повторный показ обязан
    /// вернуть её на место, а не решить, что она и так там.
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
}
