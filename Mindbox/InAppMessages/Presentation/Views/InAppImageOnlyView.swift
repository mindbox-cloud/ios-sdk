//
//  InAppImageOnlyView.swift
//  Mindbox
//
//  Created by Максим Казаков on 07.09.2022.
//

import UIKit

final class InAppImageOnlyView: UIView {
    let imageView = UIImageView()
    let uiModel: InAppMessageUIModel

    init(uiModel: InAppMessageUIModel) {
        self.uiModel = uiModel
        super.init(frame: .zero)
        customInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func customInit() {
        let image = uiModel.image
        imageView.contentMode = .scaleAspectFill
        imageView.image = image

        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
        layer.masksToBounds = true
    }
}
