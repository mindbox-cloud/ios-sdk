//
//  InAppMessageViewController.swift
//  Mindbox
//
//  Created by Максим Казаков on 07.09.2022.
//

import UIKit

final class InAppMessageViewController: UIViewController {

    init(
        inAppUIModel: InAppMessageUIModel,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onClose: @escaping (() -> Void)
    ) {
        self.inAppUIModel = inAppUIModel
        self.onPresented = onPresented
        self.onClose = onClose
        self.onTapAction = onTapAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let inAppUIModel: InAppMessageUIModel
    private let onPresented: () -> Void
    private let onClose: (() -> Void)
    private let onTapAction: InAppMessageTapAction

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black.withAlphaComponent(0.2)

        let inAppView = InAppImageOnlyView(uiModel: inAppUIModel)
        view.addSubview(inAppView)
        inAppView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inAppView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            inAppView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            inAppView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            inAppView.widthAnchor.constraint(equalTo: inAppView.heightAnchor, multiplier: 3 / 4)
        ])
        let imageTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onTapImage))
        inAppView.addGestureRecognizer(imageTapGestureRecognizer)
        inAppView.onClose = { [weak self] in self?.onClose() }

        let closeTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(onTapDimmedView))
        view.addGestureRecognizer(closeTapRecognizer)
    }


    private var viewWillAppearWasCalled = false
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !viewWillAppearWasCalled else { return }
        viewWillAppearWasCalled = true
        onPresented()
    }

    @objc private func onTapDimmedView() {
        onClose()
    }

    @objc private func onTapImage() {
        guard let redirectInfo = inAppUIModel.redirect else { return }
        onTapAction(redirectInfo.redirectUrl, redirectInfo.payload)
        onClose()
    }
}
