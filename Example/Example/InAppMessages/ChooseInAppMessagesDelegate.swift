//
//  ChooseInAppMessagesDelegate.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 02.04.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import Mindbox

class ChooseInAppMessagesDelegate: InAppMessagesDelegate {
    
    private init() {}
    static let shared = ChooseInAppMessagesDelegate()
    
    // https://developers.mindbox.ru/docs/in-app
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        //Here you can add your custom logic
        print("inAppMessageTapAction")
        print("InApp ID: \(id)")
        print("InApp URL: \(String(describing: url))")
        print("InApp Payload: \(payload)")
    }
    
    // https://developers.mindbox.ru/docs/in-app
    func inAppMessageDismissed(id: String) {
        //Here you can add your custom logic
        print("inAppMessageDismissed")
        print("InApp ID: \(id)")
    }
    
    func select(chooseInappMessageDelegate: ChooseInappMessageDelegate) {
        switch chooseInappMessageDelegate {
        case .DefaultInappMessageDelegate:
            break
        case .InAppMessagesDelegate:
            Mindbox.shared.inAppMessagesDelegate = self
        }
    }
}

enum ChooseInappMessageDelegate {
    case DefaultInappMessageDelegate
    case InAppMessagesDelegate
}
