//
//  ViewController.swift
//  ExampleApp
//
//  Created by Дмитрий Ерофеев on 11.03.2024.
//

import UIKit
import Mindbox

class ViewController: UIViewController {
    
    //Create an In-App according to these instructions:
    //https://developers.mindbox.ru/docs/in-app-targeting-by-custom-operation
    //Сreate an operation:
    //https://help.mindbox.ru/docs/%D0%BE%D0%BF%D0%B5%D1%80%D0%B0%D1%86%D0%B8%D0%B8-v-%D0%BE%D1%81%D0%BD%D0%BE%D0%B2%D0%BD%D1%8B%D0%B5-%D1%81%D0%B2%D0%B5%D0%B4%D0%B5%D0%BD%D0%B8%D1%8F
    //Change "operationSystemName" according to the name of the operation
    //For "didTapButtonAsync" and "didTapButtonSync"
    //If you don't want to test targeting by product and category use empty json like `let json = "{}"`
    @objc private func didTapButtonAsync() {
        let json = """
        { "viewProduct":
            { "product":
                { "ids":
                    { "website": "9" }
                }
            }
        }
        """
        Mindbox.shared.executeAsyncOperation(operationSystemName: "Test2", json: json)
    }
    
    @objc private func didTapButtonSync() {
        let json = """
        { "viewProduct":
            { "product":
                { "ids":
                    { "website": "94" }
                }
            }
        }
        """
        Mindbox.shared.executeSyncOperation(operationSystemName: "Test2", json: json) { result in
            switch result {
            case .success(_):
                break
            case .failure(let error):
                Mindbox.logger.log(level: .error, message: "\(error)")
            }
        }
    }
    
    let buttonAsync = UIButton()
    let buttonSync = UIButton()
    let labelDeviceUUID = UILabel()
    let buttonCopyDeviceUUID  = UIButton()
    let labelAPNSToken = UILabel()
    let buttonCopyAPNSToken  = UIButton()
    let labelSDKVerson = UILabel()
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        //https://developers.mindbox.ru/docs/ios-sdk-methods#getapnstoken
        Mindbox.shared.getAPNSToken { APNSToken in
            self.labelAPNSToken.text = APNSToken
        }
        
        //https://developers.mindbox.ru/docs/ios-sdk-methods#getdeviceuuid
        Mindbox.shared.getDeviceUUID { deviceUUID in
            self.labelDeviceUUID.text = deviceUUID
        }
        
        //https://developers.mindbox.ru/docs/ios-sdk-methods#sdkversion
        labelSDKVerson.text = "SDK version: \(Mindbox.shared.sdkVersion)"
        
        //Next comes the interface layout, which is not related to the use of SDK
        
        let defaultButtonColor = UIColor(named: "MindboxGreen")
        let defaultButtonTextColor = UIColor.white
        let defaultLabelTextColor = UIColor.black
        
        func defaultSetupButton(title: String, button: UIButton) {
            button.setTitle(title, for: .normal)
            button.backgroundColor = defaultButtonColor
            button.setTitleColor(defaultButtonTextColor, for: .normal)
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.lineBreakMode = .byWordWrapping
            button.translatesAutoresizingMaskIntoConstraints = false
        }
        
        func defaultSetupLabel(label: UILabel) {
            label.numberOfLines = 0
            label.textColor = defaultLabelTextColor
            label.translatesAutoresizingMaskIntoConstraints = false
        }
        
        func addSubViews(views: [UIView]) {
            views.forEach { v in
                view.addSubview(v)
            }
        }
        
        addSubViews(views: [buttonSync, buttonAsync, buttonCopyAPNSToken, buttonCopyDeviceUUID, labelAPNSToken, labelDeviceUUID, labelSDKVerson])
        
        view.backgroundColor = .white

        buttonAsync.addTarget(self, action: #selector(didTapButtonAsync), for: .touchUpInside)
        defaultSetupButton(title: "Show in-app (with executeAsyncOperation)", button: buttonAsync)
        
        buttonSync.addTarget(self, action: #selector(didTapButtonSync), for: .touchUpInside)
        defaultSetupButton(title: "Show in-app (with executeSyncOperation)", button: buttonSync)
        
        buttonCopyDeviceUUID.addTarget(self, action: #selector(copyDeviceUUIDToClipboard), for: .touchUpInside)
        defaultSetupButton(title: "Сopy deviceUUID to clipboard", button: buttonCopyDeviceUUID)
        
        buttonCopyAPNSToken.addTarget(self, action: #selector(copyAPNSTokenToClipboard), for: .touchUpInside)
        defaultSetupButton(title: "Сopy APNSToken to clipboard", button: buttonCopyAPNSToken)

        defaultSetupLabel(label: labelDeviceUUID)
        
        defaultSetupLabel(label: labelAPNSToken)
        
        defaultSetupLabel(label: labelSDKVerson)
        
        NSLayoutConstraint.activate([
            
            buttonAsync.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonAsync.topAnchor.constraint(equalTo: view.topAnchor, constant: 75),
            buttonAsync.widthAnchor.constraint(equalToConstant: 300),
            buttonAsync.heightAnchor.constraint(equalToConstant: 60),
            
            buttonSync.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonSync.topAnchor.constraint(equalTo: buttonAsync.bottomAnchor, constant: 25),
            buttonSync.widthAnchor.constraint(equalToConstant: 300),
            buttonSync.heightAnchor.constraint(equalToConstant: 60),
            
            labelDeviceUUID.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            labelDeviceUUID.topAnchor.constraint(equalTo: buttonSync.bottomAnchor, constant: 25),
            labelDeviceUUID.widthAnchor.constraint(equalToConstant: 300),
            
            buttonCopyDeviceUUID.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonCopyDeviceUUID.topAnchor.constraint(equalTo: labelDeviceUUID.bottomAnchor, constant: 10),
            buttonCopyDeviceUUID.widthAnchor.constraint(equalToConstant: 300),
            buttonCopyDeviceUUID.heightAnchor.constraint(equalToConstant: 40),
            
            labelAPNSToken.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            labelAPNSToken.topAnchor.constraint(equalTo: buttonCopyDeviceUUID.bottomAnchor, constant: 25),
            labelAPNSToken.widthAnchor.constraint(equalToConstant: 300),
            
            buttonCopyAPNSToken.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonCopyAPNSToken.topAnchor.constraint(equalTo: labelAPNSToken.bottomAnchor, constant: 10),
            buttonCopyAPNSToken.widthAnchor.constraint(equalToConstant: 300),
            buttonCopyAPNSToken.heightAnchor.constraint(equalToConstant: 40),
            
            labelSDKVerson.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            labelSDKVerson.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

        ])
    }
    
    @objc
    func copyDeviceUUIDToClipboard() {
        UIPasteboard.general.string = labelDeviceUUID.text
    }
    
    @objc
    func copyAPNSTokenToClipboard() {
        UIPasteboard.general.string = labelAPNSToken.text
    }
}

