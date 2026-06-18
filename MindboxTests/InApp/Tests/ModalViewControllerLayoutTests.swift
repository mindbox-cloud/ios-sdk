//
//  ModalViewControllerLayoutTests.swift
//  MindboxTests
//
//  Created by Claude on 17.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UIKit
@testable import Mindbox

/// Regression tests for the `ModalViewController` layout fix.
///
/// `viewDidLayoutSubviews()` used to rebuild the elements on *every* layout pass,
/// which caused two bugs:
///   1. an infinite layout loop (`addSubview` + constraint activation re-dirtied the
///      layout, re-triggering `viewDidLayoutSubviews`);
///   2. unbounded growth of the `elements` array (old views were removed from the
///      superview but never dropped from `self.elements`, while `setupElements`
///      kept appending).
///
/// The fix caches the inapp content size in `lastElementsLayoutSize` and only rebuilds
/// when it changes, and `setupElements()` now clears `elements` before re-adding.
@MainActor
@Suite("ModalViewController layout regression")
struct ModalViewControllerLayoutTests {

    // MARK: - Fixtures

    /// Modal config with one image background layer (source value `imageKey`) and one
    /// close-button element.
    private func makeModel(imageKey: String) throws -> ModalFormVariant {
        let json = """
        {
          "content": {
            "background": {
              "layers": [
                {
                  "$type": "image",
                  "action": { "$type": "redirectUrl", "intentPayload": "payload", "value": "https://example.com" },
                  "source": { "$type": "url", "value": "\(imageKey)" }
                }
              ]
            },
            "elements": [
              {
                "$type": "closeButton",
                "color": "#FFFFFF",
                "lineWidth": 2,
                "size": { "kind": "dp", "width": 24, "height": 24 },
                "position": { "margin": { "kind": "proportion", "top": 0.02, "right": 0.02, "left": 0.02, "bottom": 0.02 } }
              }
            ]
          }
        }
        """
        let data = Data(json.utf8)
        return try JSONDecoder().decode(ModalFormVariant.self, from: data)
    }

    private func makeImage() -> UIImage {
        let size = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeController(
        model: ModalFormVariant,
        imagesDict: [String: UIImage]
    ) -> ModalViewController {
        ModalViewController(
            model: model,
            id: "test-id",
            imagesDict: imagesDict,
            onPresented: {},
            onTapAction: { _, _ in },
            onClose: {}
        )
    }

    /// Hosts the controller in a window of the given size and forces a real layout pass,
    /// so the `InAppImageOnlyView` gets a non-zero frame.
    private func host(_ vc: UIViewController, size: CGSize) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = vc
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    // MARK: - Tests

    /// Repeated layout passes at the same size must not grow the `elements` array
    /// (guards against both the infinite loop and the array-growth bug).
    @Test("No element growth across repeated layout passes at a stable size")
    func noGrowthOnStableSize() throws {
        let key = "image-key"
        let vc = makeController(model: try makeModel(imageKey: key), imagesDict: [key: makeImage()])
        let window = host(vc, size: CGSize(width: 320, height: 568))
        defer { window.isHidden = true }

        // The first real layout builds exactly the close button.
        #expect(vc.elements.count == 1)

        // Simulate many extra layout passes at the same size.
        for _ in 0..<20 {
            vc.viewDidLayoutSubviews()
        }
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()

        #expect(vc.elements.count == 1, "elements array must not grow on stable-size layout passes")
    }

    /// Root-cause guard for the infinite-loop bug: at a stable size, `setupElements()`
    /// must NOT run again, so the element view instance stays identical across passes.
    ///
    /// This is stricter than `noGrowthOnStableSize`: because `setupElements()` now does
    /// `removeAll()` + recreate, the count would stay 1 even if the size guard were
    /// removed and the loop returned. Object identity catches a re-run that count cannot.
    @Test("Stable size does not re-run setupElements (element instance is reused)")
    func setupElementsNotReRunOnStableSize() throws {
        let key = "image-key"
        let vc = makeController(model: try makeModel(imageKey: key), imagesDict: [key: makeImage()])
        let window = host(vc, size: CGSize(width: 320, height: 568))
        defer { window.isHidden = true }

        let initialElement = try #require(vc.elements.first)

        for _ in 0..<20 {
            vc.viewDidLayoutSubviews()
            #expect(vc.elements.first === initialElement,
                    "setupElements must not re-run at a stable size — the size guard broke the layout loop")
        }
    }

    /// A genuine size change must rebuild the elements: the count stays correct (not
    /// doubled) and the previous element view is removed from the hierarchy.
    @Test("Elements are rebuilt — not duplicated — when the content size changes")
    func rebuildOnSizeChange() throws {
        let key = "image-key"
        let vc = makeController(model: try makeModel(imageKey: key), imagesDict: [key: makeImage()])
        let window = host(vc, size: CGSize(width: 320, height: 568))
        defer { window.isHidden = true }

        #expect(vc.elements.count == 1)
        let firstElement = try #require(vc.elements.first)
        #expect(firstElement.superview != nil)

        // Change the window size so the InAppImageOnlyView frame (and thus content size) changes.
        window.frame = CGRect(x: 0, y: 0, width: 414, height: 896)
        vc.view.frame = window.bounds
        window.setNeedsLayout()
        window.layoutIfNeeded()

        #expect(vc.elements.count == 1, "size change must rebuild, not append")
        let secondElement = try #require(vc.elements.first)
        #expect(secondElement !== firstElement, "a new element view should be created on rebuild")
        #expect(firstElement.superview == nil, "the previous element view must be removed from the superview")
    }

    /// When there is no `InAppImageOnlyView` in `layers` (here: the image is missing from
    /// `imagesDict`, so no layer view is created), layout must not crash and must not
    /// build any elements.
    @Test("No InAppImageOnlyView: no elements built, no crash")
    func noInappViewMeansNoElements() throws {
        let vc = makeController(model: try makeModel(imageKey: "image-key"), imagesDict: [:])
        let window = host(vc, size: CGSize(width: 320, height: 568))
        defer { window.isHidden = true }

        #expect(vc.layers.isEmpty)
        #expect(vc.elements.isEmpty)

        // Extra passes must stay safe.
        vc.viewDidLayoutSubviews()
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
        #expect(vc.elements.isEmpty)
    }
}
