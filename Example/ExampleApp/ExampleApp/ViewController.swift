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
    @objc private func didTapButtonAsync() {
        let json = "{}"
        Mindbox.shared.executeAsyncOperation(operationSystemName: "Test1",
                                             json: json)
    }
    
    //Create an In-App according to these instructions:
    //https://developers.mindbox.ru/docs/in-app-targeting-by-custom-operation
    //Сreate an operation:
    //https://help.mindbox.ru/docs/%D0%BE%D0%BF%D0%B5%D1%80%D0%B0%D1%86%D0%B8%D0%B8-v-%D0%BE%D1%81%D0%BD%D0%BE%D0%B2%D0%BD%D1%8B%D0%B5-%D1%81%D0%B2%D0%B5%D0%B4%D0%B5%D0%BD%D0%B8%D1%8F
    //Change "operationSystemName" according to the name of the operation
    @objc private func didTapButtonSync() {
        let json = "{}"
        Mindbox.shared.executeSyncOperation(operationSystemName: "Test1",
                                            json: json) { result in
            switch result {
            case .success(_):
                break
            case .failure(let mindboxError):
                Mindbox.logger.log(level: .error, message: "\(mindboxError)")
            }
        }
    }
    

    let buttonAsync = UIButton()
    let buttonSync = UIButton()
    let labelDeviceUUID = UILabel()
    let buttonCopyDeviceUUID  = UIButton()
    let labelAPNSToken = UILabel()
    let buttonCopyAPNSToken  = UIButton()
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        Mindbox.shared.getAPNSToken { APNSToken in
            self.labelAPNSToken.text = APNSToken
        }
        
        Mindbox.shared.getDeviceUUID { deviceUUID in
            self.labelDeviceUUID.text = deviceUUID
        }
        
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
        addSubViews(views: [buttonSync, buttonAsync, buttonCopyAPNSToken, buttonCopyDeviceUUID, labelAPNSToken, labelDeviceUUID])
        
        view.backgroundColor = .white

        buttonAsync.addTarget(self, action: #selector(didTapButtonAsync), for: .touchUpInside)
        defaultSetupButton(title: "Show in-app (with executeAsyncOperation)", button: buttonAsync)
        
        buttonSync.addTarget(self, action: #selector(didTapButtonAsync), for: .touchUpInside)
        defaultSetupButton(title: "Show in-app (with executeSyncOperation)", button: buttonSync)
        
        buttonCopyDeviceUUID.addTarget(self, action: #selector(copyDeviceUUIDToClipboard), for: .touchUpInside)
        defaultSetupButton(title: "Сopy deviceUUID to clipboard", button: buttonCopyDeviceUUID)
        
        buttonCopyAPNSToken.addTarget(self, action: #selector(copyAPNSTokenToClipboard), for: .touchUpInside)
        defaultSetupButton(title: "Сopy APNSToken to clipboard", button: buttonCopyAPNSToken)

        defaultSetupLabel(label: labelDeviceUUID)
        
        defaultSetupLabel(label: labelAPNSToken)
        
        NSLayoutConstraint.activate([
            
            buttonAsync.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonAsync.topAnchor.constraint(equalTo: view.topAnchor, constant: 75),
            buttonAsync.widthAnchor.constraint(equalToConstant: 250),
            buttonAsync.heightAnchor.constraint(equalToConstant: 70),
            
            buttonSync.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonSync.topAnchor.constraint(equalTo: buttonAsync.bottomAnchor, constant: 25),
            buttonSync.widthAnchor.constraint(equalToConstant: 250),
            buttonSync.heightAnchor.constraint(equalToConstant: 70),
            
            labelDeviceUUID.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            labelDeviceUUID.topAnchor.constraint(equalTo: buttonSync.bottomAnchor, constant: 75),
            labelDeviceUUID.widthAnchor.constraint(equalToConstant: 300),
            
            buttonCopyDeviceUUID.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonCopyDeviceUUID.topAnchor.constraint(equalTo: labelDeviceUUID.bottomAnchor, constant: 25),
            buttonCopyDeviceUUID.widthAnchor.constraint(equalToConstant: 250),
            buttonCopyDeviceUUID.heightAnchor.constraint(equalToConstant: 70),
            
            labelAPNSToken.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            labelAPNSToken.topAnchor.constraint(equalTo: buttonCopyDeviceUUID.bottomAnchor, constant: 75),
            labelAPNSToken.widthAnchor.constraint(equalToConstant: 300),
            
            buttonCopyAPNSToken.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonCopyAPNSToken.topAnchor.constraint(equalTo: labelAPNSToken.bottomAnchor, constant: 25),
            buttonCopyAPNSToken.widthAnchor.constraint(equalToConstant: 250),
            buttonCopyAPNSToken.heightAnchor.constraint(equalToConstant: 70),
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

