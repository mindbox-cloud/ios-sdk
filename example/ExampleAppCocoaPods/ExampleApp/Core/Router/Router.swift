//
//  Router.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/12/24.
//

import UIKit

protocol Router {
    func showWebViewController(from viewController: UIViewController, url: URL?)
    func showLogReaderViewController(from viewController: UIViewController)
}
