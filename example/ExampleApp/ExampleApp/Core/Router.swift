//
//  Router.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/12/24.
//

import UIKit

protocol Router {
    func showWebViewController(from viewController: UIViewController, url: URL?)
}

final class EARouter: Router {
    func showWebViewController(from viewController: UIViewController, url: URL?) {
        let webVC = WebViewController(url: url)
        webVC.sheetPresentationController?.detents = [.medium()]
        webVC.sheetPresentationController?.prefersGrabberVisible = true
        webVC.modalPresentationStyle = .popover
        viewController.present(webVC, animated: true)
    }
}
