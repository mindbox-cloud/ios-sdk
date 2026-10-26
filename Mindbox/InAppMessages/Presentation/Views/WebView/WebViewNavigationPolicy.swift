//
//  WebViewNavigationPolicy.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import WebKit
import MindboxLogger

enum WebViewNavigationPolicy {

    enum Decision: Equatable {

        case allow

        case handInBack(url: URL?)
    }

    static func decision(for navigationType: WKNavigationType, url: URL?) -> Decision {
        switch navigationType {
        case .other, .reload, .backForward:
            return .allow

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
