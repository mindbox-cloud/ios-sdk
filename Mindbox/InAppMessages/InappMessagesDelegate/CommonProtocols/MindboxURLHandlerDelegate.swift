//
//  MindboxURLHandlerDelegate.swift
//  Mindbox
//
//  Created by vailence on 05.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

public protocol MindboxURLHandlerDelegate {
    func openURL(_ url: URL?)
}

public extension MindboxURLHandlerDelegate {
    func openURL(_ url: URL?) {
        guard let url = url, UIApplication.shared.canOpenURL(url) else {
            Logger.common(message: "The URL does not exist or is invalid.", category: .inAppMessages)
            return
        }
        
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
