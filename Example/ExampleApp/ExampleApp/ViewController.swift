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
    
    @objc private func didTapButton() {
        let json = "{}"
        Mindbox.shared.executeSyncOperation(operationSystemName: "Test1",
                                            json: json) { result in
            print("click")
        }
    }
}

