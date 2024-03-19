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
    private var apnsToken: String = ""
    
    // MARK: Dependency Injection Private Properties

    private let router: Router
    private let factory: ButtonFactory
    
    // MARK: UI Private Properties
    
    private lazy var activityIndicator = UIActivityIndicatorView(style: .large)
    private lazy var deviceUuidLabel = UILabel(numberOfLines: 2)
    private lazy var sdkVersionLabel = UILabel(numberOfLines: 1)
    private lazy var apnsTokenLabel = UILabel(numberOfLines: 0)
    private lazy var copyDeviceUUIDButton = factory.createButton(type: .copy)
    private lazy var copyAPNSTokenButton = factory.createButton(type: .copy)
    private lazy var inAppTriggerButton = factory.createButton(type: .trigger)
    
    
    // MARK: Init
    
    init(
        router: Router = EARouter(),
        factory: ButtonFactory = EAButtonFactory()
    ) {
        self.router = router
        self.factory = factory
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
        getApnsTokenVersion()
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
    
    private func getApnsTokenVersion() {
        Mindbox.shared.getAPNSToken({ [weak self] token in
            self?.apnsToken = token
        })
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
            self.apnsTokenLabel.text = "APNS token: \(self.apnsToken)"
            self.deviceUuidLabel.text = "Device UUID:\n\(self.deviceUUID)"
            self.sdkVersionLabel.text = "SDK version: \(self.sdkVersion)"
            
            self.activityIndicator.stopAnimating()
            
            UIView.animate(withDuration: Constants.animationDuration) {
                self.sdkVersionLabel.alpha = Constants.endAlpha
                self.deviceUuidLabel.alpha = Constants.endAlpha
                self.copyDeviceUUIDButton.alpha = Constants.endAlpha
                self.copyAPNSTokenButton.alpha = Constants.endAlpha
                self.inAppTriggerButton.alpha = Constants.endAlpha
                self.apnsTokenLabel.alpha = Constants.endAlpha
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
        
        view.addSubviews(
            activityIndicator,
            apnsTokenLabel,
            deviceUuidLabel,
            copyDeviceUUIDButton,
            copyAPNSTokenButton,
            inAppTriggerButton,
            sdkVersionLabel
        )
        
        setUpActivityIndicator()
        setUpButtons()
        
        setUpConstraints()
    }
    
    func setUpConstraints() {
        NSLayoutConstraint.activate([
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            apnsTokenLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 25),
            apnsTokenLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            apnsTokenLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 25),
            apnsTokenLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -25),
            
            copyAPNSTokenButton.topAnchor.constraint(equalTo: apnsTokenLabel.bottomAnchor, constant: 15),
            copyAPNSTokenButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            copyAPNSTokenButton.widthAnchor.constraint(equalToConstant: 100),
            copyAPNSTokenButton.heightAnchor.constraint(equalToConstant: 40),
            

            deviceUuidLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            deviceUuidLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deviceUuidLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 35),
            
            copyDeviceUUIDButton.topAnchor.constraint(equalTo: deviceUuidLabel.bottomAnchor, constant: 15),
            copyDeviceUUIDButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            copyDeviceUUIDButton.widthAnchor.constraint(equalToConstant: 100),
            copyDeviceUUIDButton.heightAnchor.constraint(equalToConstant: 40),
            
            inAppTriggerButton.topAnchor.constraint(equalTo: copyDeviceUUIDButton.bottomAnchor, constant: 50),
            inAppTriggerButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            inAppTriggerButton.widthAnchor.constraint(equalToConstant: 150),
            inAppTriggerButton.heightAnchor.constraint(equalToConstant: 40),
            
            sdkVersionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -25),
            sdkVersionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    func setUpActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = Constants.mindboxColor
    }
}

// MARK: - SetUp Buttons

private extension ViewController {
    
    func setUpButtons() {
        copyDeviceUUIDButton.addTarget(self, action: #selector(copyDeviceUUIDButtonDidTap), for: .touchUpInside)
        copyAPNSTokenButton.addTarget(self, action: #selector(copyAPNSTokenButtonDidTap), for: .touchUpInside)
        inAppTriggerButton.addTarget(self, action: #selector(triggerInAppButtonDidTap), for: .touchUpInside)
    }
    
    @objc
    func copyDeviceUUIDButtonDidTap(_ sender: UIButton) {
        UIPasteboard.general.string = deviceUUID
    }
    
    @objc
    func copyAPNSTokenButtonDidTap(_ sender: UIButton) {
        UIPasteboard.general.string = apnsToken
    }
    
    @objc
    func triggerInAppButtonDidTap(_ sender: UIButton) {
        triggerInApp()
    }
}
