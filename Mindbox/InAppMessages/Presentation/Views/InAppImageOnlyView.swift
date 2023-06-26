//
//  InAppImageOnlyView.swift
//  Mindbox
//
//  Created by Максим Казаков on 07.09.2022.
//

import UIKit

final class InAppImageOnlyView: UIView {
    
    let crossImageBase64String = "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAMAAABg3Am1AAABAlBMVEUAAAD///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////85PUE7P0NBRUg+Qka9v8DAwcM9QUXNzs/CxMXKzM27vL2xsrStr7FDR0u4uru1trjHyMmqrK7P0NHa2tvS09SnqapmaWxfY2ZTVlrk5eXExcZ6fYB0d3laXmHQpZCoAAAAN3RSTlMABNgSCgi1Ft7RyL+6rKmloI4aEAzr587Fm3wgFOHQvbBgDfni38uIdWRTRyj005ZpQTKSbldOze2ocQAAAltJREFUSMd1lmlD2kAQhicHQe5QQkAKyCFWFK9eG6pQlFZsadVW/f9/RdmDnckm8yWbnedddjdzABv7Wu6wsPDZhRQLxqXuKF/9KF+zBSasfpTMj+sSKA84v8O29iEBt3ztbwQAsMeQ+Vacdz3sLwMcM2K9DOVrTeq/gAqjVggwn83F3BXo8Of64WUhp/I1zb+z5eTq8f4fH3RgyJ/3UTS9UidzFP9e3cevKIqe+GgI4soeIqToOgl89MyHIYhD3c2xolHj+yH8zzUfl6AlJmdE0XQB2mr/Pzj/W7x8AedEKqZv0/OZhDzLzWP+m+RPAeBcOq6Ioloi/HfxMuTh5CcqknjWF8HiYcXlAvNLwh+CsO12b+KK5VTzODRrXVNh8mc4ZGyi+I/5a+na1TgOmlutWJl8uuIunceBjBUr/lD8JzDNUXclUCFTnxFxOBmxAvMtSDZrVyswfwipAn0MfeB0QVDEvFKkH8E5wB9vTi61Ypl8OxYeNCx6GWP9XDxkqaIYr1cNmhRmaO8Rhds0eJQ85m9YRYM305l5+uRlhkuH5E1FRfFnzCw1RolBKddK5nER+6OLgK73i0vMVytJipMJgDXC/I3ESvwiTIUH0E/iCxmAgQqVv1gxAVHhrgl/MODBYhPFWqaGrcv9rQRyjszzHax4lk0ulA1F86ftbUPZR4onsVmwZct6nKn1JU8US9WyeuAzanm5H9SEsLXg2Gyi2LIN6p/EGnvZSJQBbfybNXjjTU9eC3XyXMBvTyVDmPLnpF+XgKda+FFpn4XFcxdSLDPujeq2f7EZvwIvrFdkd3alfwAAAABJRU5ErkJggg=="

    var onClose: (() -> Void)?
    let imageView = UIImageView()
    let closeButton = UIButton(frame: .zero)
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
        
        var closeImage: UIImage?
        if let base64Image = base64ToImage(base64String: crossImageBase64String) {
            closeImage = base64Image
        }

        closeButton.setImage(closeImage, for: .normal)
        closeButton.contentVerticalAlignment = .fill
        closeButton.contentHorizontalAlignment = .fill
        closeButton.imageView?.contentMode = .scaleAspectFit
        closeButton.addTarget(self, action: #selector(onTapCloseButton), for: .touchUpInside)
        addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        layer.masksToBounds = true
    }
    
    func base64ToImage(base64String: String) -> UIImage? {
        if let data = Data(base64Encoded: base64String) {
            return UIImage(data: data)
        }
        return nil
    }

    @objc func onTapCloseButton() {
        self.onClose?()
    }
}
