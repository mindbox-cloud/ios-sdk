//
//  InAppMessageViewController.swift
//  Mindbox
//
//  Created by Максим Казаков on 07.09.2022.
//

import UIKit

class InAppMessageViewController: UIViewController {

    var onClose: (() -> Void)?
    let inAppView = InAppMessageImageView(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gray.withAlphaComponent(0.4)

        view.addSubview(inAppView)
        inAppView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inAppView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            inAppView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            inAppView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            inAppView.heightAnchor.constraint(equalToConstant: 350)
        ])
        inAppView.onClose = { [weak self] in self?.onClose?() }
    }
}

class InAppMessageImageView: UIView {

    var onClose: (() -> Void)?
    let imageView = UIImageView()
    let closeButton = UIButton(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        customInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        customInit()
    }

    func customInit() {
        let bundle = Bundle(for: InAppMessageImageView.self)
        // TODO: Remove testImage from resources when downloading image from server is ready
        let testImage = UIImage(named: "testImage", in: bundle, compatibleWith: nil)
        imageView.contentMode = .scaleAspectFill
        imageView.image = testImage

        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)

        let closeImage = UIImage(named: "cross", in: bundle, compatibleWith: nil)
        closeButton.setImage(closeImage, for: .normal)
        closeButton.addTarget(self, action: #selector(onTapCloseButton), for: .touchUpInside)
        addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: self.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        backgroundColor = .white
        layer.cornerRadius = 16
        layer.masksToBounds = true
    }

    @objc func onTapCloseButton() {
        self.onClose?()
    }
}
