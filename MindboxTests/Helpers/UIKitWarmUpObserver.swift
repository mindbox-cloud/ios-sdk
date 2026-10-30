//
//  UIKitWarmUpObserver.swift
//  MindboxTests
//
//  Created by Sergei Semko on 06.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import XCTest

// Loaded via Info.plist NSPrincipalClass: with no host app, the first UIWindow cold-starts UIKit (over a minute on CI).
@objc(UIKitWarmUpObserver)
final class UIKitWarmUpObserver: NSObject, XCTestObservation {

    override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testBundleWillStart(_ testBundle: Bundle) {
        let start = CFAbsoluteTimeGetCurrent()
        _ = UIWindow()
        print(String(format: "[MindboxTests] UIKit warm-up took %.3f s", CFAbsoluteTimeGetCurrent() - start))
    }
}
