//
//  EmbeddedBlockPageHosting.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

protocol EmbeddedBlockPageHosting: AnyObject {

    var view: UIView { get }

    var onContentRendered: ((Int) -> Void)? { get set }

    var onUnreadableContentReport: (() -> Void)? { get set }

    var onShowableQuestion: (([String], @escaping ([String]) -> Void) -> Void)? { get set }

    var onShowInAppRequest: ((String, [String: JSONValue], @escaping (Result<Void, BridgeErrorCode>) -> Void) -> Void)? { get set }

    var onDataPushConfirmed: (() -> Void)? { get set }

    var onLoadFailure: ((String) -> Void)? { get set }

    var isUserPresent: Bool { get set }

    func load()

    func cancel()

    func sendInitData(params: [String: JSONValue])
}

extension EmbeddedBlockPageHosting {

    func detachCallbacks() {
        onContentRendered = nil
        onUnreadableContentReport = nil
        onShowableQuestion = nil
        onShowInAppRequest = nil
        onDataPushConfirmed = nil
        onLoadFailure = nil
    }
}
