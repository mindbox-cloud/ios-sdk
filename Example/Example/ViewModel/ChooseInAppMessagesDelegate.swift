//
//  ChooseInAppMessagesDelegate.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 02.04.2024.
//

import Foundation
import Mindbox

class ChooseInAppMessagesDelegate: InAppMessagesDelegate {
    
    private init() {}
    static var shared = ChooseInAppMessagesDelegate()
    
    //https://developers.mindbox.ru/docs/in-app
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        //Here you can add your custom logic
        print("inAppMessageTapAction")
        print(id)
        print(url ?? "")
        print(payload)
    }
    
    //https://developers.mindbox.ru/docs/in-app
    func inAppMessageDismissed(id: String) {
        //Here you can add your custom logic
        print("inAppMessageDismissed")
        print(id)
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
