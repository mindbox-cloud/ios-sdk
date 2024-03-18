//
//  ViewController.swift
//  ExampleApp
//
//  Created by Дмитрий Ерофеев on 11.03.2024.
//

import UIKit
import Mindbox

class ViewController: UIViewController {
    
    let buttonAsync = UIButton()
    let buttonSync = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        buttonAsync.setTitle("Show in-app (with executeAsyncOperation)", for: .normal)
        view.addSubview(buttonAsync)
        buttonAsync.backgroundColor = UIColor(red: 55/255, green: 169/255, blue: 92/255, alpha: 1)
        buttonAsync.setTitleColor(.white, for: .normal)
        buttonAsync.addTarget(self, action: #selector(didTapButtonAsync), for: .touchUpInside)
        buttonAsync.titleLabel?.numberOfLines = 0
        buttonAsync.titleLabel?.lineBreakMode = .byWordWrapping
        buttonAsync.translatesAutoresizingMaskIntoConstraints = false
        
        buttonSync.setTitle("Show in-app (with executeSyncOperation)", for: .normal)
        view.addSubview(buttonSync)
        buttonSync.backgroundColor = UIColor(red: 55/255, green: 169/255, blue: 92/255, alpha: 1)
        buttonSync.setTitleColor(.white, for: .normal)
        buttonSync.addTarget(self, action: #selector(didTapButtonAsync), for: .touchUpInside)
        buttonSync.titleLabel?.numberOfLines = 0
        buttonSync.titleLabel?.lineBreakMode = .byWordWrapping
        buttonSync.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            
            buttonAsync.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonAsync.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            buttonAsync.widthAnchor.constraint(equalToConstant: 250),
            buttonAsync.heightAnchor.constraint(equalToConstant: 100),
            
            buttonSync.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonSync.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 100),
            buttonSync.widthAnchor.constraint(equalToConstant: 250),
            buttonSync.heightAnchor.constraint(equalToConstant: 100),
        ])
    }
    
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
            case .success(let operationResponse):
                break
            case .failure(let mindboxError):
                Mindbox.logger.log(level: .error, message: "\(mindboxError)")
            }
        }
    }
}

