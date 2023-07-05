//
//  MindboxURLHandlerDelegate.swift
//  Mindbox
//
//  Created by vailence on 05.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit

public protocol MindboxURLHandlerDelegate {
    func openURL(_ url: URL?)
}

public extension MindboxURLHandlerDelegate {
    func openURL(_ url: URL?) {
        guard let url = url, UIApplication.shared.canOpenURL(url) else {
            return
        }
        
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
