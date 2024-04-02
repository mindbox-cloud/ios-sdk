//
//  EARouter.swift
//  ExampleApp
//
//  Created by Sergei Semko on 4/2/24.
//

import UIKit

final class EARouter: Router {
    func showLogReaderViewController(from viewController: UIViewController) {
        let vc = LogReaderViewController()
        viewController.present(vc, animated: true)
    }
    
    func showWebViewController(from viewController: UIViewController, url: URL?) {
        let webVC = WebViewController(url: url)
        webVC.sheetPresentationController?.detents = [.medium()]
        webVC.sheetPresentationController?.prefersGrabberVisible = true
        webVC.modalPresentationStyle = .popover
        viewController.present(webVC, animated: true)
    }
}
