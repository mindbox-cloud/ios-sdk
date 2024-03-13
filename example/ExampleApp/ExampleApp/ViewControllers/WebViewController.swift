//
//  WebViewController.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/12/24.
//

import UIKit
import WebKit

final class WebViewController: UIViewController {
    
    private var url: URL?
    
    private lazy var webView: WKWebView = {
        let webConfiguration = WKWebViewConfiguration()
        let wView = WKWebView(frame: .zero, configuration: webConfiguration)
        wView.uiDelegate = self
        return wView
    }()
    
    init(url: URL?) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = webView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadUrlRequest()
    }
    
    private func loadUrlRequest() {
        guard let url else {
            return
        }
        let request = URLRequest(url: url)
        webView.load(request)
    }
}


// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate { }
