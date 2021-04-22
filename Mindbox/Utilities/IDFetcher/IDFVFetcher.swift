//
//  IDFVFetcher.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit.UIDevice

struct IDFVFetcher {
    
    typealias Completion = (UUID?) -> Void
    
    func fetch(tryCount: Int, completion: @escaping Completion) {
        var countdown = tryCount

        let timer = Timer(timeInterval: 1, repeats: true) { (timer) in
            guard countdown > 0 else {
                completion(nil)
                return
            }
            if let udid = UIDevice.current.identifierForVendor, isValid(udid: udid.uuidString) {
                completion(udid)
                timer.invalidate()
            }
            countdown -= 1
        }
        timer.fire()
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private func isValid(udid: String) -> Bool {
        return UDIDValidator(udid: udid).evaluate()
    }
    
}
