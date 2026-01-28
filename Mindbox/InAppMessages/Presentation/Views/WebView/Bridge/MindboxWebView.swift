//
//  MindboxWebView.swift
//  Mindbox
//
//  Created by vailence on 17.10.2024.
//

import UIKit
import WebKit
import MindboxLogger

final class MindboxWebView: WKWebView {
    init(userAgent: String) {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = userAgent

        super.init(frame: .zero, configuration: config)

        #if DEBUG
        if #available(iOS 16.4, *) {
            self.isInspectable = true
        }
        #endif
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
