//
//  ViewController.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/11/24.
//

import UIKit
import Mindbox

final class ViewController: UIViewController {
    
    private var deviceUUID: String = ""
    private var sdkVersion: String = ""
    
    // MARK: Dependency Injection Private Properties

    private let router: Router
    
    // MARK: UI Private Properties
    
    private lazy var activityIndicator = UIActivityIndicatorView(style: .large)
    private lazy var deviceUuidLabel = UILabel()
    private lazy var sdkVersionLabel = UILabel()
    private lazy var copyButton = UIButton(type: .system)
    private lazy var inAppTriggerButton = UIButton(type: .system)
    
    
    // MARK: Init
    
    init(
        router: Router = EARouter()
    ) {
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
        getDeviceUUID()
        getSdkVersion()
        setUpDelegates()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showDeviceUUIDandSDKVersion()
    }
    
    // MARK: Private methods
    
    private func getDeviceUUID() {
        // https://developers.mindbox.ru/docs/ios-sdk-methods#getdeviceuuid
        Mindbox.shared.getDeviceUUID { deviceUUID in
            self.deviceUUID = deviceUUID
        }
        
        Mindbox.logger.log(level: .info, message: "Device UUID: \(self.deviceUUID)")
    }
    
    private func getSdkVersion() {
        // https://developers.mindbox.ru/docs/ios-sdk-methods#sdkversion
        sdkVersion = Mindbox.shared.sdkVersion
        
        Mindbox.logger.log(level: .info, message: "SDK version: \(sdkVersion)")
    }
    
    private func triggerInApp() {
        activityIndicator.startAnimating()
        
        /// https://developers.mindbox.ru/docs/in-app-targeting-by-custom-operation#ios
        let operationSystemName = "InAppTestOperationIOSExampleApp"
        let operationBody = OperationBodyRequest()
        
        // https://developers.mindbox.ru/docs/ios-integration-actions
        // https://developers.mindbox.ru/docs/ios-integration-actions#передача-и-получение-данных-от-mindbox--синхронное-выполнение
        Mindbox.shared.executeSyncOperation(
            operationSystemName: operationSystemName,
            operationBody: operationBody
        ) { [weak self] result in
            switch result {
            case .success(let operationResponse):
                Mindbox.logger.log(
                    level: .info,
                    message: "Operation \(operationSystemName) succeeded. Response: \(operationResponse)"
                )
            case .failure(let mindboxError):
                Mindbox.logger.log(
                    level: .info,
                    message: "Operation \(operationSystemName) failed. Error: \(mindboxError.localizedDescription)"
                )
            }
            
            self?.activityIndicator.stopAnimating()
        }
    }
    
    private func registerCustomer() {
        // https://developers.mindbox.ru/docs/ios-integration-actions#передача-данных-в-mindbox--асинхронное-выполнение
        let operationSystemName = "CustomerOperationIOSExampleApp"
        let operationBody = OperationBodyRequest()
        
        operationBody.customer = .init(
            birthDate: Date().asDateOnly,
            sex: .female,
            lastName: "Surname",
            firstName: "Name",
            middleName: nil,
            email: "example@example.com",
            ids: ["websideid": "id"],
            customFields: .init(
                [
                    "ExtraField": "Value",
                    "NewExtraField": "NewValue"
                ]
            ),
            subscriptions: [
                .init(
                    brand: "Brand",
                    pointOfContact: .email,
                    topic: "Topic",
                    isSubscribed: true
                )
            ]
        )
        
        Mindbox.shared.executeAsyncOperation(
            operationSystemName: operationSystemName,
            operationBody: operationBody
        )
    }
    
    private func setUpDelegates() {
        Mindbox.shared.inAppMessagesDelegate = self
    }
    
    private func showDeviceUUIDandSDKVersion() {
        activityIndicator.startAnimating()
        
        DispatchQueue.main.async {
            self.deviceUuidLabel.text = self.deviceUUID
            self.sdkVersionLabel.text = "SDK version: \(self.sdkVersion)"
            
            self.activityIndicator.stopAnimating()
            
            UIView.animate(withDuration: 0.5) {
                self.sdkVersionLabel.alpha = 1
                self.deviceUuidLabel.alpha = 1
                self.copyButton.alpha = 1
                self.inAppTriggerButton.alpha = 1
            }
        }
    }
}

// MARK: - InAppMessagesDelegate
/// Overriding the behavior when tapping on the InApp
/// Default behavior: https://developers.mindbox.ru/docs/in-app#defaultinappmessagedelegate

//https://developers.mindbox.ru/docs/in-app#inappmessagesdelegate
extension ViewController: InAppMessagesDelegate {
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        Mindbox.logger.log(level: .debug, message: """
            Id: \(id)
            url: \(String(describing: url))
            payload: \(payload)
        """)
        
        router.showWebViewController(from: self, url: url)
    }
    
    func inAppMessageDismissed(id: String) {
        Mindbox.logger.log(level: .debug, message: "Dismiss InAppView")
    }
}

// MARK: - SetUp Layout

private extension ViewController {
    
    func setUpLayout() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(activityIndicator)
        view.addSubview(deviceUuidLabel)
        view.addSubview(copyButton)
        view.addSubview(inAppTriggerButton)
        view.addSubview(sdkVersionLabel)
        
        setUpUIViews()
        setUpButtons()
        
        setUpConstraints()
    }
    
    func setUpConstraints() {
        NSLayoutConstraint.activate([
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            deviceUuidLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            deviceUuidLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deviceUuidLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            copyButton.topAnchor.constraint(equalTo: deviceUuidLabel.bottomAnchor, constant: 25),
            copyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 100),
            copyButton.heightAnchor.constraint(equalToConstant: 40),
            
            inAppTriggerButton.topAnchor.constraint(equalTo: copyButton.bottomAnchor, constant: 25),
            inAppTriggerButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            inAppTriggerButton.widthAnchor.constraint(equalToConstant: 150),
            inAppTriggerButton.heightAnchor.constraint(equalToConstant: 40),
            
            sdkVersionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -25),
            sdkVersionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    func setUpUIViews() {
        // SetUp SDKVersionLabel
        sdkVersionLabel.translatesAutoresizingMaskIntoConstraints = false
        sdkVersionLabel.textAlignment = .center
        sdkVersionLabel.alpha = 0
        
        // SetUp DeviceUUIDLabel
        deviceUuidLabel.translatesAutoresizingMaskIntoConstraints = false
        deviceUuidLabel.textAlignment = .center
        deviceUuidLabel.alpha = 0
        
        // SetUp ActivityIndicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = Constants.mindboxColor
    }
}

// MARK: - SetUp Buttons

private extension ViewController {
    
    func setUpButtons() {
        setUpCopyButton()
        copyButton.addTarget(self, action: #selector(copyButtonDidTap), for: .touchUpInside)
        
        setUpInAppTriggerButton()
        inAppTriggerButton.addTarget(self, action: #selector(triggerInAppButtonDidTap), for: .touchUpInside)
    }
    
    func setUpCopyButton() {
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.setTitle(Constants.copyButtonTitle, for: .normal)
        copyButton.setImage(
            UIImage(systemName: Constants.copyButtonSystemImageName),
            for: .normal
        )
        copyButton.backgroundColor = Constants.mindboxColor
        copyButton.tintColor = .white
        copyButton.alpha = 0
        copyButton.layer.cornerRadius = 15
    }
    
    func setUpInAppTriggerButton() {
        inAppTriggerButton.translatesAutoresizingMaskIntoConstraints = false
        inAppTriggerButton.setTitle(Constants.inAppTriggerButtonTitle, for: .normal)
        inAppTriggerButton.setImage(
            UIImage(systemName: Constants.inAppTriggerButtonSystemImageName),
            for: .normal
        )
        inAppTriggerButton.backgroundColor = Constants.mindboxColor
        inAppTriggerButton.tintColor = .white
        inAppTriggerButton.alpha = 0
        inAppTriggerButton.layer.cornerRadius = 15
    }
    
    @objc
    func copyButtonDidTap(_ sender: UIButton) {
        UIPasteboard.general.string = deviceUUID
    }
    
    @objc
    func triggerInAppButtonDidTap(_ sender: UIButton) {
        triggerInApp()
    }
}

fileprivate enum Constants {
    static let copyButtonTitle = "Copy"
    static let copyButtonSystemImageName = "doc.on.doc"
    
    static let inAppTriggerButtonTitle = "Trigger In-App"
    static let inAppTriggerButtonSystemImageName = "icloud.and.arrow.up"
    
    static let mindboxColor = UIColor(
        red: 91 / 255,
        green: 168 / 255,
        blue: 101 / 255,
        alpha: 1
    )
}
