//
//  MainViewModel.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//

import Foundation
import Mindbox

class MainViewModel: ObservableObject {
    
    @Published var SDKVersion: String = ""
    @Published var deviceUUID: String = ""
    @Published var APNSToken: String = ""
    
    init() {
        setupData()
    }
    
    func setupData() {
        self.SDKVersion = Mindbox.shared.sdkVersion
//        DispatchQueue.main.async {
//            Mindbox.shared.getDeviceUUID { deviceUUID in
//                self.deviceUUID = deviceUUID
//            }
//        }
//        DispatchQueue.main.async {
//            Mindbox.shared.getAPNSToken { APNSToken in
//                self.APNSToken = APNSToken
//            }
//        }
        //DispatchQueue.main.async {
            Mindbox.shared.getDeviceUUID { deviceUUID in
                DispatchQueue.main.async {
                    self.deviceUUID = deviceUUID
                }
            }
        //}
        Mindbox.shared.getAPNSToken { APNSToken in
            DispatchQueue.main.async {
                self.APNSToken = APNSToken
            }
        }
    }
    
    func showInAppWithExecuteSyncOperation () {
        let json = """
        { "viewProduct":
            { "product":
                { "ids":
                    { "website": "94" }
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
    
    func showInAppWithExecuteAsyncOperation () {
        let json = """
        { "viewProduct":
            { "product":
                { "ids":
                    { "website": "9" }
                }
            }
        }
        """
        Mindbox.shared.executeAsyncOperation(operationSystemName: "APIMethodForReleaseExampleIos", json: json)
    }
}
