//
//  MindboxApp.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 08.10.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import UIKit

@available(iOS 11.0, *)
public final class MindboxApp {

    @discardableResult
    public static func configure() -> Bool {
        MindboxAppDelegateProxy.configure()
        return true
    }
}
