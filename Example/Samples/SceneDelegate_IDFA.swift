//
//  SceneDelegate_IDFA.swift
//  Example
//
//  Created by Sergei Semko on 03.11.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import AdSupport
import AppTrackingTransparency
import Mindbox
import SwiftUI
import UIKit

// Pass the IDFA to Mindbox on every scene activation, with or without tracking consent: without consent iOS
// returns zeros, and Mindbox then clears the IDFA it received earlier. Never skip the call without consent.
// The scene also becomes active when the ATT alert closes, so this one call site covers the user's answer.
//
// The IDFA is sent only if PrivacyInfo.xcprivacy sets NSPrivacyTracking to true and lists the tracking
// host (api-tracking.mindbox.ru for api.mindbox.ru). Never list the main API host there.

// UIKit
class SceneDelegate_IDFA: UIResponder, UIWindowSceneDelegate {

    func sceneDidBecomeActive(_ scene: UIScene) {
        Mindbox.shared.setAdvertisingIdentifier(ASIdentifierManager.shared().advertisingIdentifier)
    }
}

// UIKit, when the app already checks the tracking status: pass nil when tracking is not authorized
@available(iOS 14, *)
class SceneDelegate_IDFAWithStatusCheck: UIResponder, UIWindowSceneDelegate {

    func sceneDidBecomeActive(_ scene: UIScene) {
        if ATTrackingManager.trackingAuthorizationStatus == .authorized {
            Mindbox.shared.setAdvertisingIdentifier(ASIdentifierManager.shared().advertisingIdentifier)
        } else {
            Mindbox.shared.setAdvertisingIdentifier(nil)
        }
    }
}

// SwiftUI, iOS 17+
struct App_IDFA: App {

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Text("Mindbox")
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Mindbox.shared.setAdvertisingIdentifier(ASIdentifierManager.shared().advertisingIdentifier)
        }
    }
}
