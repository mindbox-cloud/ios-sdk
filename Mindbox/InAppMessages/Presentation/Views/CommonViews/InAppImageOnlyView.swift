//
//  InAppImageOnlyView.swift
//  Mindbox
//
//  Created by Максим Казаков on 07.09.2022.
//

import UIKit
import MindboxLogger

final class InAppImageOnlyView: UIView {
    var onClose: (() -> Void)?
    let imageView = UIImageView()
    let image: UIImage?
    let action: ContentBackgroundLayerAction?

    init(image: UIImage, action: ContentBackgroundLayerAction?) {
        self.image = image
        self.action = action
        super.init(frame: .zero)
        customInit()
    }

    required init?(coder: NSCoder) {
        self.image = nil
        self.action = nil
        super.init(coder: coder)
        customInit()
    }

    func customInit() {
        guard let image = image else {
            Logger.common(message: "[Error]: \(#function) at line \(#line) of \(#file)", level: .error)
            return
        }
        
        Logger.common(message: "InAppImageOnlyView custom init started.")
        
        imageView.contentMode = .scaleAspectFill
        imageView.image = image
        imageView.layer.opacity = 0.5

        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
        layer.masksToBounds = true
    }
}
