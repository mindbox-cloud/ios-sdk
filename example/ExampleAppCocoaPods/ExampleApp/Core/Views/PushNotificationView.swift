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
        
        stackView.alpha = Constants.startAlpha
        
        return stackView
    }()
    
    private lazy var pushNotificationInfoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22)
        label.text = Constants.pushNotificationInfoTitle
        label.isHidden = true
        return label
    }()
    
    private lazy var urlFromPushLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        return label
    }()
    
    private lazy var payloadLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 3
        return label
    }()
    
    private lazy var firstButtonLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 3
        return label
    }()
    
    private lazy var secondButtonLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 3
        return label
    }()
    
    private lazy var thirdButtonLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 3
        return label
    }()
    
    private lazy var buttonLabels: [UILabel] = [
        firstButtonLabel,
        secondButtonLabel,
        thirdButtonLabel
    ]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func fillData(buttons: [(text: String?, url: String?)], urlFromPush: String, payload: String) {
        UIView.animate(withDuration: Constants.animationDuration) {
            self.stackView.alpha = Constants.startAlpha
        } completion: { flag in
            UIView.animate(withDuration: Constants.animationDuration) {
                self.stackView.alpha = Constants.endAlpha
            }
        }

        pushNotificationInfoLabel.isHidden = false
        
        urlFromPushLabel.text = !urlFromPush.isEmpty ? "URL from push: \"\(urlFromPush)\"" : "URL from push: \(Constants.emptyString)"
        
        if !payload.isEmpty {
            payloadLabel.isHidden = false
            payloadLabel.text = "Payload: \"\(payload)\""
        } else {
            payloadLabel.isHidden = true
            payloadLabel.text = "Payload: \(Constants.emptyString)"
        }
        
        buttonLabels.forEach { $0.isHidden = true }
        
        if !buttons.isEmpty {
            for (index, button) in buttons.enumerated() where index < buttonLabels.count {
                
                let buttonLabel = buttonLabels[index]
                
                buttonLabel.isHidden = false
                
                let buttonText = button.text ?? Constants.emptyString
                let buttonUrl = button.url ?? Constants.emptyString
                
                buttonLabel.text = "Button \(index + 1):\nText: \"\(buttonText)\" \nURL: \"\(buttonUrl)\""
            }
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
