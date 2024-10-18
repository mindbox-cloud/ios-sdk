//
//  TransparentWebView.swift
//  Mindbox
//
//  Created by vailence on 17.10.2024.
//

import UIKit
import WebKit

final class TransparentWebView: UIView {
    private let webView = WKWebView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupWebView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebView()
    }

    private func setupWebView() {
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.bounces = false
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.isScrollEnabled = true

        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func getHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="ru">
        <head>
        <meta charset="utf-8">
        <title>Сайт для тестирования форм</title>
        <script>
        mindbox = window.mindbox || function() { mindbox.queue.push(arguments); };
        mindbox.queue = mindbox.queue || [];
        mindbox('create', {
        endpointId: 'test-staging.personalization-test-site-staging.mindbox.ru'
        });
        </script>
        <script src="https://api-staging.mindbox.ru/scripts/v1/tracker.js" async></script>
        </head>
        </html>
        """
    }

    func load() {
        let url = URL(string: "file://hello")
        webView.loadHTMLString(getHTML(), baseURL: url)
    }
}
