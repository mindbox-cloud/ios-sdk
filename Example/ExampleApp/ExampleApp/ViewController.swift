//
//  ViewController.swift
//  ExampleApp
//
//  Created by Дмитрий Ерофеев on 11.03.2024.
//

import UIKit
import Mindbox

class ViewController: UIViewController {
    
    let button = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        button.setTitle("Show in-app", for: .normal)
        view.addSubview(button)
        button.backgroundColor = UIColor(red: 55/255, green: 169/255, blue: 92/255, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 200),
            button.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    //Create an In-App according to these instructions:
    //https://developers.mindbox.ru/docs/in-app-targeting-by-custom-operation
    //Сreate an operation:
    //https://help.mindbox.ru/docs/%D0%BE%D0%BF%D0%B5%D1%80%D0%B0%D1%86%D0%B8%D0%B8-v-%D0%BE%D1%81%D0%BD%D0%BE%D0%B2%D0%BD%D1%8B%D0%B5-%D1%81%D0%B2%D0%B5%D0%B4%D0%B5%D0%BD%D0%B8%D1%8F
    //Change "operationSystemName" according to the name of the operation
    @objc private func didTapButton() {
        let json = "{}"
        Mindbox.shared.executeAsyncOperation(operationSystemName: "Test1",
                                             json: json)
    }
}

