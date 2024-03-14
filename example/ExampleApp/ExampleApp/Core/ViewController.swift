//
//  ViewController.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/11/24.
//

import UIKit
import Mindbox
import OSLog

fileprivate enum Constants {
    static let copyButtonTitle = "Copy"
    static let copyButtonSystemImageName = "doc.on.doc"
    
    static let inAppTriggerButtonTitle = "Trigger In-App"
    static let inAppTriggerButtonSystemImageName = "icloud.and.arrow.up"
}

final class ViewController: UIViewController {
    
    private var deviceUUID: String
    
    private let router: Router
    
    private let plistReader: PlistReaderOperation
    
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
    
    init(
        deviceUUID: String = String(),
        router: Router = EARouter(),
        plistReader: PlistReaderOperation = EAPlistReader.shared
    ) {
        self.deviceUUID = deviceUUID
        self.router = router
        self.plistReader = plistReader
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
        Mindbox.logger.logLevel = .default
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showDeviceUUID()
    }
}

// MARK: - InAppMessagesDelegate

extension ViewController: InAppMessagesDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Mindbox.logger.log(level: .debug, message: """
            Function: \(#function)
            Id: \(id)
            url: \(String(describing: url))
            payload: \(payload)
        """)
        
        router.showWebViewController(from: self, url: url)
    }
    
    func inAppMessageDismissed(id: String) {
        Mindbox.logger.log(level: .debug, message: """
            Function: \(#function)
        """)
    }
}

// MARK: - SetUp ViewController

private extension ViewController {
    
    // MARK: SetUp Layout

    func setUpLayout() {
        view.backgroundColor = .systemBackground
        view.addSubviews(
            deviceUuidLabel,
            copyButton,
            inAppTriggerButton
        )
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
    
    // MARK: SetUp Buttons
    
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
        /// https://developers.mindbox.ru/docs/in-app-targeting-by-custom-operation
        let operationSystemName = plistReader.operationSystemName
        let operationBody = OperationBodyRequest()
        
        Mindbox.shared.executeAsyncOperation(
            operationSystemName: operationSystemName,
            operationBody: operationBody
        )
    }
    
    // MARK: Private methods

    func showDeviceUUID() {
        DispatchQueue.main.async {
            self.deviceUuidLabel.text = self.deviceUUID
        }
    }
    
    func getDeviceUUID() {
        Mindbox.shared.getDeviceUUID { deviceUUID in
            self.deviceUUID = deviceUUID
        }
        
        Logger.pushNotifications.log("Device UUID: \(self.deviceUUID)")
    }
}
