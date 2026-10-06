//
//  UIKitWarmUpObserver.swift
//  MindboxTests
//
//  Created by Sergei Semko on 06.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import XCTest

// The bundle has no host app, so the first UIWindow in the process starts UIKit, which can take over
// a minute on CI. Paying it here keeps it out of every test's execution time allowance.
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
