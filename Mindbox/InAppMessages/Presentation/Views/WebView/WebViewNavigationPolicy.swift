//
//  WebViewNavigationPolicy.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import WebKit
import MindboxLogger

/// What a Mindbox web view may navigate to — one policy for every surface.
enum WebViewNavigationPolicy {

    enum Decision: Equatable {

        /// Our own load: the content commit, a reload, a back-forward move.
        case allow

        /// Anything the user started: cancelled and handed to the page to decide.
        case handInBack(url: URL?)
    }

    static func decision(for navigationType: WKNavigationType, url: URL?) -> Decision {
        switch navigationType {
        case .other, .reload, .backForward:
            return .allow

        // `@unknown` included: a navigation type we cannot name is not one we let through.
        default:
            return .handInBack(url: url)
        }
    }

    static func log(_ decision: Decision,
                    navigationType: WKNavigationType,
                    url: URL?,
                    category: LogCategory) {
        let urlString = url?.absoluteString ?? "unknown"

        switch decision {
        case .allow:
            Logger.common(message: "[WebView] Allowing navigation (\(navigationType.debugLabel)) to \(urlString)",
                          category: category)
        case .handInBack:
            Logger.common(message: "[WebView] Blocking navigation (\(navigationType.debugLabel)) to \(urlString). Forwarding to JS.",
                          category: category)
        }
    }
}

extension WKNavigationType {

    var debugLabel: String {
        switch self {
        case .linkActivated:    return "linkActivated"
        case .formSubmitted:    return "formSubmitted"
        case .backForward:      return "backForward"
        case .reload:           return "reload"
        case .formResubmitted:  return "formResubmitted"
        case .other:            return "other"
        @unknown default:       return "unknown(\(rawValue))"
        }
    }
}
