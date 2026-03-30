//
//  WebBridgeWKScriptMessageDelegate.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 28.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import WebKit

/// Test-only hook used by internal test apps to observe raw incoming `WKScriptMessage` objects.
///
/// This is meant purely for visual/debug purposes (e.g. to display the unparsed message payload),
/// and must not be used by production code or relied upon as part of the SDK API contract.
@_spi(Internal)
public protocol WebBridgeWKScriptMessageDelegate: AnyObject {
    func webBridge(_ bridge: MindboxWebBridge, didReceiveFromJS message: WKScriptMessage)
}
