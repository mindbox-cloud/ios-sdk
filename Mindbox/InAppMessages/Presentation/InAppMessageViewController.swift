//
//  InAppMessageViewController.swift
//  Mindbox
//
//  Created by Максим Казаков on 07.09.2022.
//

import UIKit

final class InAppMessageViewController: UIViewController {

    init(inAppUIModel: InAppMessageUIModel, onClose: @escaping (() -> Void)) {
        self.inAppUIModel = inAppUIModel
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let inAppUIModel: InAppMessageUIModel
    private let onClose: (() -> Void)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gray.withAlphaComponent(0.4)

        let inAppView = InAppImageOnlyView(uiModel: inAppUIModel)
        view.addSubview(inAppView)
        inAppView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inAppView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            inAppView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            inAppView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            inAppView.widthAnchor.constraint(equalTo: inAppView.heightAnchor, multiplier: 3 / 4)
        ])
        inAppView.onClose = { [weak self] in self?.onClose() }
    }
}
