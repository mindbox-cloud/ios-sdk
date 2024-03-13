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
    
    static let inAppTriggerButtonTitle = "Trigger In-App"
    static let inAppTriggerButtonSystemImageName = "icloud.and.arrow.up"
}

final class ViewController: UIViewController {
    
    private var deviceUUID: String
    
    private let router: Router
    
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
    
    private lazy var inAppTriggerButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(Constants.inAppTriggerButtonTitle, for: .normal)
        button.setImage(
            UIImage(systemName: Constants.inAppTriggerButtonSystemImageName),
            for: .normal
        )
        return button
    }()
    
    // MARK: Init

    init(deviceUUID: String = String(), router: Router = EARouter()) {
        self.deviceUUID = deviceUUID
        self.router = router
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpLayout()
        setUpButtons()
        getDeviceUUID()
        Mindbox.shared.inAppMessagesDelegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showDeviceUUID()
    }
}

//extension ViewController: URLInappMessageDelegate {
//    
//}
//
//extension ViewController: CopyInappMessageDelegate {
//    
//}

// MARK: - InAppMessagesDelegate

extension ViewController: InAppMessagesDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        print(#function)
        print("""
            Id: \(id)
            url: \(url)
            payload: \(payload)
        """)
        
        router.showWebViewController(from: self, url: url)
    }
    
    func inAppMessageDismissed(id: String) {
        print(#function)
    }
}

// MARK: - SetUp Layout

private extension ViewController {
    func setUpLayout() {
        view.backgroundColor = .systemBackground
        view.addSubview(deviceUuidLabel)
        view.addSubview(copyButton)
        view.addSubview(inAppTriggerButton)
        NSLayoutConstraint.activate([
            deviceUuidLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            deviceUuidLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deviceUuidLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            copyButton.topAnchor.constraint(equalTo: deviceUuidLabel.bottomAnchor, constant: 25),
            copyButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            copyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            inAppTriggerButton.topAnchor.constraint(equalTo: copyButton.bottomAnchor, constant: 25),
            inAppTriggerButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            inAppTriggerButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    func setUpButtons() {
        copyButton.addTarget(self, action: #selector(copyButtonDidTap), for: .touchUpInside)
        inAppTriggerButton.addTarget(self, action: #selector(triggerInApp), for: .touchUpInside)
    }
    
    @objc
    func copyButtonDidTap(_ sender: UIButton) {
        UIPasteboard.general.string = deviceUUID
        triggerInApp(sender)
    }
    
    @objc
    func triggerInApp(_ sender: UIButton) {
        let operationSystemName = "InAppTestOperationIOSExampleApp"
        let json = "{}"
        
        Mindbox.shared.executeAsyncOperation(
            operationSystemName: operationSystemName,
            json: json
        )
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
