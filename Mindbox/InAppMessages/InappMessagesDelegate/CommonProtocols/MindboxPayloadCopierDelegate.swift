//
//  MindboxPayloadCopierDelegate.swift
//  Mindbox
//
//  Created by vailence on 05.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit

public protocol MindboxPayloadCopierDelegate {
    func copyPayload(_ payload: String)
}

public extension MindboxPayloadCopierDelegate {
    func copyPayload(_ payload: String) {
        if !payload.isEmpty, payload.isPlainString() {
            UIPasteboard.general.string = payload
        }
    }
}
