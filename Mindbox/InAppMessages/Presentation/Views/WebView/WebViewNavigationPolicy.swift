//
//  WebViewNavigationPolicy.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import WebKit
import MindboxLogger

/// What a Mindbox web view is allowed to navigate to.
///
/// One policy for every surface. The content load is ours to perform, and a navigation the user started
/// is the page's business to decide, not the web view's to perform: an overlay that followed a link
/// would replace the in-app with a web page, and a block would do it inside someone else's list.
enum WebViewNavigationPolicy {

    enum Decision: Equatable {

        /// Our own load: the content commit, a reload, a back-forward move.
        case allow

        /// Anything the user started. Cancelled here and handed to the page, which knows whether it
        /// wanted a browser, a deep link or nothing at all.
        case handInBack(url: URL?)
    }

    static func decision(for navigationType: WKNavigationType, url: URL?) -> Decision {
        switch navigationType {
        case .other, .reload, .backForward:
            return .allow

        // Every remaining case, `@unknown` included: a navigation type we cannot name is not one we
        // should let through.
        default:
            return .handInBack(url: url)
        }
    }

    /// Logging is separate from deciding so that a surface can name itself in its own log category
    /// while both keep one wording.
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
