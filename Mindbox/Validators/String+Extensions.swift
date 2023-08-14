//
//  String+Extensions.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
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
    
    func isHexValid() -> Bool {
        if !self.hasPrefix("#") {
            return false
        }
        
        let hexValue = String(self.dropFirst())
        
        if hexValue.count != 6 {
            return false
        }
            
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        return hexValue.unicodeScalars.allSatisfy { hexCharacterSet.contains($0) }
    }
}
