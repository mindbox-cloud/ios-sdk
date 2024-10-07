//
//  MainViewModel.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import Mindbox
import Observation

@Observable final class MainViewModel {
    
    var SDKVersion: String = ""
    var deviceUUID: String = ""
    var APNSToken: String = ""
    
    private var timer: Timer?
    
    //https://developers.mindbox.ru/docs/ios-sdk-methods
    func setupData() {
        self.SDKVersion = Mindbox.shared.sdkVersion
        Mindbox.shared.getDeviceUUID { deviceUUID in
            DispatchQueue.main.async {
                self.deviceUUID = deviceUUID
            }
        }
        startDeviceUUIDChecking()
        Mindbox.shared.getAPNSToken { APNSToken in
            DispatchQueue.main.async {
                self.APNSToken = APNSToken
            }
        }
        ChooseInAppMessagesDelegate.shared.select(chooseInappMessageDelegate: .InAppMessagesDelegate)
    }
    
    private func startDeviceUUIDChecking() {
        guard self.deviceUUID.isEmpty else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Mindbox.shared.getDeviceUUID { deviceUUID in
                DispatchQueue.main.async {
                    if !deviceUUID.isEmpty {
                        self.deviceUUID = deviceUUID
                        self.stopDeviceUUIDChecking()
                    }
                }
            }
        }
    }
    
    private func stopDeviceUUIDChecking() {
        timer?.invalidate()
        timer = nil
    }
    
    //https://developers.mindbox.ru/docs/in-app-targeting-by-custom-operation
    func showInAppWithExecuteSyncOperation () {
        let json = """
        { "viewProduct":
            { "product":
                { "ids":
                    { "website": "1" }
                }
            }
        }
        """
        Mindbox.shared.executeSyncOperation(operationSystemName: "APIMethodForReleaseExampleIos", json: json) { result in
            switch result {
            case .success(let success):
                Mindbox.logger.log(level: .info, message: "\(success)")
            case .failure(let error):
                Mindbox.logger.log(level: .error, message: "\(error)")
            }
        }
    }
    
    //https://developers.mindbox.ru/docs/in-app-targeting-by-custom-operation
    func showInAppWithExecuteAsyncOperation () {
        let json = """
        { "viewProduct":
            { "product":
                { "ids":
                    { "website": "2" }
                }
            }
        }
        """
        Mindbox.shared.executeAsyncOperation(operationSystemName: "APIMethodForReleaseExampleIos", json: json)
    }
}
