//
//  SnackbarViewController.swift
//  Mindbox
//
//  Created by vailence on 16.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit

class SnackbarViewController: UIViewController {
    
    var snackbarView: SnackbarView?
    var edgeConstraint: NSLayoutConstraint?
    
    var layers = [UIView]()
    var elements = [UIView]()
    private let elementFactories: [ContentElementType: ElementFactory] = [
        .closeButton: CloseButtonElementFactory()
    ]
    
    private let layersFactories: [ContentBackgroundLayerType: LayerFactory] = [
        .image: ImageLayerFactory()
    ]

    private let model: SnackbarFormVariant
    private let id: String
    public let image: UIImage
    private let onPresented: () -> Void
    private let onClose: () -> Void
    private let onTapAction: (ContentBackgroundLayerAction?) -> Void
    
    private var hasSetupLayers = false
    private var hasSetupElements = false
    
    enum Constants {
        static let animationDuration: TimeInterval = 0.5
        static let screenPart: CGFloat = 3.0
        static let oneThirdScreenHeight: CGFloat = UIScreen.main.bounds.height / Constants.screenPart
    }

    init(
        model: SnackbarFormVariant,
        id: String,
        image: UIImage,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping (ContentBackgroundLayerAction?) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.model = model
        self.id = id
        self.image = image
        self.onPresented = onPresented
        self.onClose = onClose
        self.onTapAction = onTapAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = true
        snackbarView = SnackbarView(onClose: onClose)
        if let snackbarView = snackbarView {
            snackbarView.translatesAutoresizingMaskIntoConstraints = false
            snackbarView.isUserInteractionEnabled = true
            view.addSubview(snackbarView)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hasSetupLayers {
            hasSetupLayers = true
            setupConstraints()
            setupLayers()

            if snackbarView?.bounds.size != .zero {
                setupElements()
                hasSetupElements = true
            }
        } else if !hasSetupElements && snackbarView?.bounds.size != .zero {
            setupElements()
            hasSetupElements = true
        }
    }
    
    private func setupLayers() {
        let layers = model.content.background.layers.elements
        guard let snackbarView = snackbarView else {
            return
        }
        
        for layer in layers {
            if let factory = layersFactories[layer.layerType] {
                let layerView = factory.create(from: self.image, layer: layer, in: snackbarView, with: self)
                if let layerView = layerView {
                    self.layers.append(layerView)
                    snackbarView.addSubview(layerView)
                    factory.setupConstraintsSnackbar(for: layerView, in: snackbarView)
                }
            }
        }
    }
    
    private func setupElements() {
        guard let elements = model.content.elements?.elements,
              let snackbarView = snackbarView else {
            return
        }
        
        for element in elements {
            if let factory = elementFactories[element.elementType] {
                let elementView = factory.create(from: element, in: snackbarView, with: self)
                if let elementView = elementView {
                    self.elements.append(elementView)
                    snackbarView.addSubview(elementView)
                    factory.setupConstraints(for: elementView, from: element, in: snackbarView)
                }
            }
        }
    }

    var swipeDirection: UISwipeGestureRecognizer.Direction {
        fatalError("This method must be overridden")
    }
    
    func setupConstraints() {
        fatalError("This method must be overridden")
    }
    
    private func animateConstraints(withDuration duration: TimeInterval) {
        view.layoutIfNeeded()
        
        UIView.animate(withDuration: duration) {
            self.edgeConstraint?.constant = 0
            self.view.layoutIfNeeded()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateConstraints(withDuration: Constants.animationDuration)
        onPresented()
    }
}

extension SnackbarViewController: GestureHandler {
    @objc func imageTapped(_ sender: UITapGestureRecognizer) {
        guard let imageView = sender.view as? InAppImageOnlyView else {
            return
        }
        
        let action = imageView.action
        onTapAction(action)
    }
    
    @objc func onCloseButton(_ gesture: UILongPressGestureRecognizer) {
        guard let crossView = gesture.view else {
            return
        }
        
        let location = gesture.location(in: crossView)
        let isInsideCrossView = crossView.bounds.contains(location)
        if gesture.state == .ended && isInsideCrossView {
            onClose()
        }
    }
}

class TopSnackbarViewController: SnackbarViewController {
    override var swipeDirection: UISwipeGestureRecognizer.Direction {
        return .up
    }
    
    override func setupConstraints() {
        let imageHeight = self.image.size.height
        var safeAreaBottomOffset: CGFloat = 0
        if #available(iOS 11.0, *) {
            safeAreaBottomOffset = view.safeAreaInsets.top
        }

        let finalHeight = (imageHeight < Constants.oneThirdScreenHeight) ? imageHeight : Constants.oneThirdScreenHeight

        self.view.frame = CGRect(x: 0, y: 0,
                                 width: UIScreen.main.bounds.width,
                                 height: finalHeight + safeAreaBottomOffset)
        
        guard let snackbarView = snackbarView else {
            return
        }
        
        snackbarView.swipeDirection = .up
        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                snackbarView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                snackbarView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                snackbarView.heightAnchor.constraint(equalToConstant: finalHeight),
            ])
        }
       
        setupBottomConstraint(with: finalHeight)
    }

    private func setupBottomConstraint(with height: CGFloat) {
        if #available(iOS 11.0, *) {
            edgeConstraint = snackbarView?.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -height)
            edgeConstraint?.isActive = true
        }
    }
}

class BottomSnackbarViewController: SnackbarViewController {

    override var swipeDirection: UISwipeGestureRecognizer.Direction {
        return .down
    }
    
    override func setupConstraints() {
        let imageHeight = self.image.size.height
        let screenHeight = UIScreen.main.bounds.height
        var safeAreaBottomOffset: CGFloat = 0
        if #available(iOS 11.0, *) {
            safeAreaBottomOffset = view.safeAreaInsets.bottom
        }
        let finalHeight = (imageHeight < Constants.oneThirdScreenHeight) ? imageHeight : Constants.oneThirdScreenHeight

        self.view.frame = CGRect(x: 0, y: screenHeight - finalHeight - safeAreaBottomOffset,
                                 width: UIScreen.main.bounds.width,
                                 height: finalHeight + safeAreaBottomOffset)
        guard let snackbarView = snackbarView else {
            return
        }
        snackbarView.swipeDirection = .down
        
        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                snackbarView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                snackbarView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                snackbarView.heightAnchor.constraint(equalToConstant: finalHeight),
            ])
        }
       
        setupBottomConstraint(with: finalHeight)
    }

    private func setupBottomConstraint(with height: CGFloat) {
        if #available(iOS 11.0, *) {
            edgeConstraint = snackbarView?.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: height)
            edgeConstraint?.isActive = true
        }
    }
}
