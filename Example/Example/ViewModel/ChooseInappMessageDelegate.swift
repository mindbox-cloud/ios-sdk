//
//  ChooseInappMessageDelegate.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 01.04.2024.
//

import Foundation
import Mindbox

enum ChooseInappMessageDelegate {
    case DefaultInappMessageDelegate
    case InAppMessagesDelegate
    
    static func select(chooseInappMessageDelegate: ChooseInappMessageDelegate, action: () -> ()) {
        switch chooseInappMessageDelegate {
        case .DefaultInappMessageDelegate:
            break
        case .InAppMessagesDelegate:
            action()
        }
    }
}
