//
//  MainViewModel.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//

import Foundation
import Mindbox
import UIKit

class MainViewModel: ObservableObject {
    
    @Published var SDKVersion: String = ""
    @Published var deviceUUID: String = ""
    @Published var APNSToken: String = ""
    
    //https://developers.mindbox.ru/docs/ios-sdk-methods
    func setupData() {
        self.SDKVersion = Mindbox.shared.sdkVersion
        Mindbox.shared.getDeviceUUID { deviceUUID in
            DispatchQueue.main.async {
                self.deviceUUID = deviceUUID
            }
        }
        Mindbox.shared.getAPNSToken { APNSToken in
            DispatchQueue.main.async {
                self.APNSToken = APNSToken
            }
        }
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




