//
//  String+Extension.swift
//  Mindbox
//
//  Created by vailence on 05.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit

extension String {
    func isPlainString() -> Bool {
        if let data = self.data(using: .utf8) {
            do {
                try JSONSerialization.jsonObject(with: data, options: [])
                return false
            } catch {
            }
        }
        
        if let data = self.data(using: .utf8) {
            let parser = XMLParser(data: data)
            if parser.parse() {
                return false
            }
        }
        
        if let url = URL(string: self), UIApplication.shared.canOpenURL(url) {
            return false
        }

        return true
    }
}
