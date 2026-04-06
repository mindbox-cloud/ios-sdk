//
//  NSError+Extensions.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 03.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

extension NSError {
    var isNetworkOrTimeoutError: Bool {
        domain == NSURLErrorDomain && [
            NSURLErrorTimedOut,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorDataNotAllowed,
            NSURLErrorCannotConnectToHost,
            NSURLErrorDNSLookupFailed
        ].contains(code)
    }
}
