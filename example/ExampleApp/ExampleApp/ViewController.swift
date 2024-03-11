//
//  ViewController.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/11/24.
//

import UIKit
import Mindbox

fileprivate enum Constants {
    static let copyButtonTitle = "Copy"
    static let copyButtonSystemImageName = "doc.on.doc"
}

final class ViewController: UIViewController {
    
    private var deviceUUID = String()
    
    private lazy var deviceUuidLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    private lazy var copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(Constants.copyButtonTitle, for: .normal)
        button.setImage(
            UIImage(systemName: Constants.copyButtonSystemImageName),
            for: .normal
        )
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpLayout()
        setUpButton()
        getDeviceUUID()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showDeviceUUID()
    }
}

private extension ViewController {
    func setUpLayout() {
        view.backgroundColor = .systemBackground
        view.addSubview(deviceUuidLabel)
        view.addSubview(copyButton)
        NSLayoutConstraint.activate([
            deviceUuidLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            deviceUuidLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deviceUuidLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            copyButton.topAnchor.constraint(equalTo: deviceUuidLabel.bottomAnchor, constant: 25),
            copyButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            copyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    func setUpButton() {
        copyButton.addTarget(self, action: #selector(copyButtonDidTap), for: .touchUpInside)
    }
    
    @objc
    func copyButtonDidTap(_ sender: UIButton) {
        let pastboard = UIPasteboard.general
        pastboard.string = deviceUUID
    }
    
    func showDeviceUUID() {
        DispatchQueue.main.async {
            self.deviceUuidLabel.text = self.deviceUUID
        }
    }
    
    func getDeviceUUID() {
        Mindbox.shared.getDeviceUUID { deviceUUID in
            self.deviceUUID = deviceUUID
        }
    }
}
