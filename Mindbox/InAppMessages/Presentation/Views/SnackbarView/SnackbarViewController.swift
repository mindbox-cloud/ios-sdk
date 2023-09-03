//
//  SnackbarViewController.swift
//  Mindbox
//
//  Created by vailence on 16.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

class SnackbarViewController: UIViewController, InappViewControllerProtocol {
    
    var snackbarView: SnackbarView?
    var edgeConstraint: NSLayoutConstraint?
    let model: SnackbarFormVariant
    
    var layers = [UIView]()
    var elements = [UIView]()
    
    let elementFactories: [ContentElementType: ElementFactory] = [
        .closeButton: CloseButtonElementFactory()
    ]
    
    let layersFactories: [ContentBackgroundLayerType: LayerFactory] = [
        .image: ImageLayerFactory()
    ]
    
    var leftOffset: CGFloat {
        return model.content.position?.margin?.element?.left ?? 0
    }
    
    var rightOffset: CGFloat {
        return model.content.position?.margin?.element?.right ?? 0
    }

    private let id: String
    private let imagesDict: [String: UIImage]
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
        imagesDict: [String: UIImage],
        onPresented: @escaping () -> Void,
        onTapAction: @escaping (ContentBackgroundLayerAction?) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.model = model
        self.id = id
        self.imagesDict = imagesDict
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
            UIView.performWithoutAnimation {
                setupElements()
                hasSetupElements = true
                view.layoutIfNeeded()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateConstraints(withDuration: Constants.animationDuration)
        onPresented()
    }
    
    private func setupLayers() {
        let layers = model.content.background.layers.elements
        guard let snackbarView = snackbarView else {
            return
        }
        
        for layer in layers {
            if let factory = layersFactories[layer.layerType] {
                if case .image(let imageContentBackgroundLayer) = layer {
                    if case .url(let urlModel) = imageContentBackgroundLayer.source, let image = imagesDict[urlModel.value] {
                        let layerView = factory.create(from: image, layer: layer, in: view, with: self)
                        if let layerView = layerView {
                            self.layers.append(layerView)
                            snackbarView.addSubview(layerView)
                            factory.setupConstraintsSnackbar(for: layerView, in: snackbarView)
                        }
                    }
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
                let elementView = factory.create(from: element, with: self)
                if let elementView = elementView {
                    self.elements.append(elementView)
                    snackbarView.addSubview(elementView)
                    factory.setupConstraints(for: elementView, from: element, in: snackbarView)
                }
            }
        }
    }

    var swipeDirection: UISwipeGestureRecognizer.Direction {
        return .down
    }
    
    private func animateConstraints(withDuration duration: TimeInterval) {
        view.layoutIfNeeded()
        
        UIView.animate(withDuration: duration) {
            self.edgeConstraint?.constant = 0
            self.view.layoutIfNeeded()
        }
    }
    
    func setupConstraints() {
        guard let firstImageKey = imagesDict.keys.first, let image = imagesDict[firstImageKey] else {
            return
        }
        
        let width = view.layer.frame.width - leftOffset - rightOffset
        let heightMultiplier = width / image.size.width
        let imageHeight = image.size.height * heightMultiplier
        let finalHeight = (imageHeight < Constants.oneThirdScreenHeight) ? imageHeight : Constants.oneThirdScreenHeight
        
        setViewFrame(with: finalHeight)
        guard let snackbarView = snackbarView else {
            return
        }
        
        snackbarView.swipeDirection = swipeDirection
        snackbarView.translatesAutoresizingMaskIntoConstraints = false
        
        setupLayoutConstraints(with: finalHeight)
        setupEdgeConstraint(with: finalHeight)
    }

    func setViewFrame(with height: CGFloat) {
        // Need override in sub-class.
    }

    func setupLayoutConstraints(with height: CGFloat) {
        guard let snackbarView = snackbarView else {
            return
        }
        
        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                snackbarView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                snackbarView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                snackbarView.heightAnchor.constraint(equalToConstant: height),
            ])
        } else {
            NSLayoutConstraint.activate([
                snackbarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                snackbarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                snackbarView.heightAnchor.constraint(equalToConstant: height),
            ])
        }
    }
    
    func setupEdgeConstraint(with height: CGFloat) {
        Logger.common(message: "Method setupEdgeConstraint must be overriden in subclass.")
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
            snackbarView?.hide()
        }
    }
}

class TopSnackbarViewController: SnackbarViewController {
    override var swipeDirection: UISwipeGestureRecognizer.Direction {
        return .up
    }

    override func setViewFrame(with height: CGFloat) {
        var safeAreaTopOffset: CGFloat = 0
        if #available(iOS 11.0, *) {
            safeAreaTopOffset = view.safeAreaInsets.top
        }

        let finalHeight = height + safeAreaTopOffset

        self.view.frame = CGRect(x: leftOffset, y: 0,
                                 width: UIScreen.main.bounds.width - leftOffset - rightOffset,
                                 height: finalHeight)
    }

    override func setupEdgeConstraint(with height: CGFloat) {
        if #available(iOS 11.0, *) {
            edgeConstraint = snackbarView?.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -height)
        } else {
            edgeConstraint = snackbarView?.topAnchor.constraint(equalTo: view.topAnchor, constant: -height)
        }
        
        edgeConstraint?.isActive = true
    }
}

class BottomSnackbarViewController: SnackbarViewController {

    override var swipeDirection: UISwipeGestureRecognizer.Direction {
        return .down
    }
    
    override func setViewFrame(with height: CGFloat) {
        let screenHeight = UIScreen.main.bounds.height
        var safeAreaBottomOffset: CGFloat = 0
        if #available(iOS 11.0, *) {
            safeAreaBottomOffset = view.safeAreaInsets.bottom
        }
        
        let finalHeight = height + safeAreaBottomOffset

        self.view.frame = CGRect(x: leftOffset, y: screenHeight - finalHeight,
                                 width: UIScreen.main.bounds.width - leftOffset - rightOffset,
                                 height: finalHeight)
    }

    override func setupEdgeConstraint(with height: CGFloat) {
        if #available(iOS 11.0, *) {
            edgeConstraint = snackbarView?.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: height)
        } else {
            edgeConstraint = snackbarView?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: height)
        }
        
        edgeConstraint?.isActive = true
    }
}
