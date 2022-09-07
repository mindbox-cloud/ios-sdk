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

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onCloseInAppMessage))
        view.addGestureRecognizer(tapGesture)

        view.addSubview(inAppView)
        inAppView.bounds.size = .init(width: 150, height: 250)
    }

    override func viewDidLayoutSubviews() {
        inAppView.center = view.center
    }

    @objc func onCloseInAppMessage() {
        onClose?()
    }
}

class InAppMessageImageView: UIView {

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
        // TODO: Remove testImage from resources!
        let testImage = UIImage(named: "testImage", in: bundle, compatibleWith: nil)
        imageView.contentMode = .scaleAspectFill
        imageView.image = testImage

        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)

        backgroundColor = .white
        layer.cornerRadius = 16
        layer.masksToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
