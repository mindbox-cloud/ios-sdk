//
//  FetchUtilities.swift
//  MindBox
//
//  Created by Mikhail Barilov on 20.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import AdSupport
import AppTrackingTransparency
import UIKit.UIDevice

class FetchUtilities: IFetchUtilities {

    let sdkBundle = Bundle.init(for: MindBox.self)
    let appBundle = Bundle.main

    init() {

    }

    private var advertising: UUID? {
        get {
            // Firstly, Check whether advertising tracking is enabled
            guard ASIdentifierManager.shared().isAdvertisingTrackingEnabled else {
                return nil
            }
            // Then, Get and return IDFA
            return ASIdentifierManager.shared().advertisingIdentifier
        }
    }

    var appVerson: String? {
        appBundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
    }
    var sdkVersion: String? {
        get {
            return sdkBundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String

        }
    }

    var hostApplicationName: String? {
        get {
            return appBundle.bundleIdentifier
        }
    }

    func getIDFA(
        onSuccess: @escaping ((UUID)->Void),
        onFail: @escaping (()->Void) // alwas on simul
    ) {
        func getAndExecute() {
            DispatchQueue.global().async {


                if let id = self.advertising, Utilities.checkUUID(string: id.uuidString) {
                    onSuccess(id)
                } else {
                    onFail()
                }
            }
        }

        if #available(iOS 14, *) {
            switch ATTrackingManager.trackingAuthorizationStatus {
            case .authorized:
                getAndExecute()
            case .notDetermined:
                guard Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") !=  nil else {
                    // FIX: add Log
                    onFail()
                    return
                }
                ATTrackingManager.requestTrackingAuthorization { (status) in
                    if status == .authorized {
                        getAndExecute()
                    } else {
                        onFail()
                    }
                }
            default:
                onFail()
            }
        } else {
            getAndExecute()
        }
    }

    func getIDFV(
        tryCount: Int,
        onSuccess: @escaping ((UUID)->Void),
        onFail: @escaping (()->Void)
    ) {
		var countdown = tryCount
        func fetchAndValidate() -> Bool {
            if let idfv = UIDevice.current.identifierForVendor {
                onSuccess(idfv)
                return true
            }
            return false
        }

        let timer = Timer(timeInterval: 1, repeats: true) { (timer) in
            guard countdown > 0 else {
                onFail()
                return
            }
            if fetchAndValidate() {
                timer.invalidate()
            }
            countdown -= 1
        }

        timer.fire()
        RunLoop.current.add(timer, forMode: .common)

    }

}
