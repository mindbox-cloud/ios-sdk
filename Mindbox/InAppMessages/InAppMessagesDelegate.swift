//
//  InAppMessagesDelegate.swift
//  Mindbox
//
//  Created by Максим Казаков on 21.09.2022.
//

import Foundation

public protocol InAppMessagesDelegate: AnyObject {
    func inAppMessageTapAction(id: String, url: URL?, payload: String)

    func inAppMessageDismissed(id: String)
}

extension InAppMessagesDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {}

    func inAppMessageDismissed(id: String) {}
}
