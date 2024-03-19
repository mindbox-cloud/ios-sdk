//
//  PushNotificationView.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/19/24.
//

import UIKit

final class PushNotificationView: UIView {
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
//        stackView.isHidden = true
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fillProportionally
        stackView.spacing = 10
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = .init(top: 10, left: 10, bottom: 10, right: 10)
        
        stackView.layer.cornerRadius = Constants.cornerRadius
        stackView.layer.cornerCurve = .continuous
        stackView.layer.borderColor = Constants.mindboxColor.cgColor
        stackView.layer.borderWidth = 1
        
        stackView.alpha = 0
        
        return stackView
    }()
    
    private lazy var pushNotificationInfoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22)
        label.text = "PushNotification Info"
        label.isHidden = true
        return label
    }()
    
    private lazy var urlFromPushLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var payloadLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var firstButtonLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
//        label.textAlignment = .center
        return label
    }()
    
    private lazy var secondButtonLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
//        label.textAlignment = .center
        return label
    }()
    
    private lazy var thirdButtonLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
//        label.textAlignment = .center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func fillData(buttons: [(text: String?, url: String?)], urlFromPush: String, payload: String) {
//        stackView.isHidden = false
        UIView.animate(withDuration: 1) {
            self.stackView.alpha = 1
        }
        pushNotificationInfoLabel.isHidden = false
        if !urlFromPush.isEmpty {
            urlFromPushLabel.text = "URL from push: \(urlFromPush)"
        } else {
            urlFromPushLabel.text = "URL from push: Empty"
        }
        
        if !payload.isEmpty {
            payloadLabel.isHidden = false
            payloadLabel.text = "Payload: \(payload)"
        } else {
            payloadLabel.isHidden = true
            payloadLabel.text = "Payload: Empty"
        }
        
        if !buttons.isEmpty {
            firstButtonLabel.isHidden = false
            secondButtonLabel.isHidden = false
            thirdButtonLabel.isHidden = false
            for (index, button) in buttons.enumerated() {
                
                if index == 0 {
                    firstButtonLabel.text = "Button \(index + 1):\nText: \(button.text ?? "Empty"),\nURL: \(button.url ?? "Empty")"
                }
                if index == 1 {
                    secondButtonLabel.text = "Button \(index + 1):\nText: \(button.text ?? "Empty"),\nURL: \(button.url ?? "Empty")"
                }
                if index == 2 {
                    thirdButtonLabel.text = "Button \(index + 1):\nText: \(button.text ?? "Empty"),\nURL: \(button.url ?? "Empty")"
                }
            }
        } else {
            firstButtonLabel.isHidden = true
            secondButtonLabel.isHidden = true
            thirdButtonLabel.isHidden = true
//            firstButtonLabel.alpha = 0
//            secondButtonLabel.alpha = 0
//            thirdButtonLabel.alpha = 0
        }
    }
    
    private func setUpLayout() {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = .systemBackground
        
        self.addSubviews(
            stackView
        )
        
        stackView.addArrangedSubviews(
            pushNotificationInfoLabel,
            urlFromPushLabel,
            payloadLabel,
            firstButtonLabel,
            secondButtonLabel,
            thirdButtonLabel
        )
        
        setUpConstraints()
    }
    
    private func setUpConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])
    }
}
