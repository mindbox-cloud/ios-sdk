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
        return model.content.position.margin.left
    }
    
    var rightOffset: CGFloat {
        return model.content.position.margin.right
    }

    private let imagesDict: [String: UIImage]
    let snackbarView: SnackbarView
    private let firstImageValue: String
    private let onPresented: () -> Void
    private let onTapAction: (ContentBackgroundLayerAction?) -> Void
    
    private var hasSetupLayers = false
    private var hasSetupElements = false
    
    enum Constants {
        static let animationDuration: TimeInterval = 0.5
        static let screenPart: CGFloat = 3.0
        static let oneThirdScreenHeight: CGFloat = UIScreen.main.bounds.height / Constants.screenPart
        static let edgeConstraint: CGFloat = .zero
        static let initialSafeAreaTopOffset: CGFloat = .zero
        static let initialSafeAreaBottomOffset: CGFloat = .zero
        static let topOffset: CGFloat = .zero
    }

    init(
        model: SnackbarFormVariant,
        imagesDict: [String: UIImage],
        snackbarView: SnackbarView,
        firstImageValue: String,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping (ContentBackgroundLayerAction?) -> Void
    ) {
        self.model = model
        self.imagesDict = imagesDict
        self.snackbarView = snackbarView
        self.firstImageValue = firstImageValue
        self.onPresented = onPresented
        self.onTapAction = onTapAction
        super.init(nibName: nil, bundle: nil)
        Logger.common(message: "SnackbarViewController inited.")
    }

    required init?(coder: NSCoder) {
        Logger.common(message: "SnackbarViewController init(coder:) has not been implemented.")
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(snackbarView)
        view.isUserInteractionEnabled = true
        snackbarView.translatesAutoresizingMaskIntoConstraints = false
        snackbarView.isUserInteractionEnabled = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hasSetupLayers {
            hasSetupLayers = true
            setupConstraints()
            setupLayers()

            if snackbarView.bounds.size != .zero {
                setupElements()
                hasSetupElements = true
            }
        } else if !hasSetupElements && snackbarView.bounds.size != .zero {
            Logger.common(message: "In-app snackbar height: [\(snackbarView.frame.height)]")
            Logger.common(message: "In-app snackbar width: [\(snackbarView.frame.width)]")
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
        let layers = model.content.background.layers
    
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
        for element in model.content.elements {
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
            self.edgeConstraint?.constant = Constants.edgeConstraint
            self.view.layoutIfNeeded()
        }
    }
    
    func setupConstraints() {
        guard let image = imagesDict[firstImageValue] else {
            Logger.common(message: "[Error]: \(#function) at line \(#line) of \(#file)", level: .error)
            return
        }
        
        let width = view.layer.frame.width
        let heightMultiplier = width / image.size.width
        let imageHeight = image.size.height * heightMultiplier
        let finalHeight = (imageHeight < Constants.oneThirdScreenHeight) ? imageHeight : Constants.oneThirdScreenHeight
        
        setViewFrame(with: finalHeight)
        
        snackbarView.swipeDirection = swipeDirection
        snackbarView.translatesAutoresizingMaskIntoConstraints = false
        
        setupLayoutConstraints(with: finalHeight)
        setupEdgeConstraint(with: finalHeight)
    }

    func setViewFrame(with height: CGFloat) {
        // Need override in sub-class.
    }

    func setupLayoutConstraints(with height: CGFloat) {
        if #available(iOS 11.0, *) {
            Logger.common(message: "SnackbarViewController setupLayoutConstraints iOS 11+.")
            NSLayoutConstraint.activate([
                snackbarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                snackbarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                snackbarView.heightAnchor.constraint(equalToConstant: height),
            ])
        } else {
            Logger.common(message: "SnackbarViewController setupLayoutConstraints iOS 10.")
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
            Logger.common(message: "[Error]: \(#function) at line \(#line) of \(#file)", level: .error)
            return
        }
        
        let action = imageView.action
        onTapAction(action)
    }
    
    @objc func onCloseButton(_ gesture: UILongPressGestureRecognizer) {
        guard let crossView = gesture.view else {
            Logger.common(message: "[Error]: \(#function) at line \(#line) of \(#file)", level: .error)
            return
        }
        
        let location = gesture.location(in: crossView)
        let isInsideCrossView = crossView.bounds.contains(location)
        if gesture.state == .ended && isInsideCrossView {
            snackbarView.hide()
        }
    }
}

class TopSnackbarViewController: SnackbarViewController {
    override var swipeDirection: UISwipeGestureRecognizer.Direction {
        return .up
    }

    override func setViewFrame(with height: CGFloat) {
        var safeAreaTopOffset: CGFloat = Constants.initialSafeAreaTopOffset
        if #available(iOS 11.0, *) {
            safeAreaTopOffset = view.safeAreaInsets.top
        }

        let finalHeight = height + safeAreaTopOffset

        self.view.frame = CGRect(x: leftOffset, y: Constants.topOffset,
                                 width: UIScreen.main.bounds.width - leftOffset - rightOffset,
                                 height: finalHeight)
    }

    override func setupEdgeConstraint(with height: CGFloat) {
        if #available(iOS 11.0, *) {
            edgeConstraint = snackbarView.topAnchor.constraint(equalTo: view.topAnchor, constant: -height)
        } else {
            edgeConstraint = snackbarView.topAnchor.constraint(equalTo: view.topAnchor, constant: -height)
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
        var safeAreaBottomOffset: CGFloat = Constants.initialSafeAreaBottomOffset
        if #available(iOS 11.0, *) {
            safeAreaBottomOffset = view.safeAreaInsets.bottom
        }
        
        let finalHeight = height + safeAreaBottomOffset

        self.view.frame = CGRect(x: leftOffset, y: screenHeight - finalHeight,
                                 width: UIScreen.main.bounds.width - leftOffset - rightOffset,
                                 height: finalHeight)
        Logger.common(message: "SnackbarViewController setViewFrame function finished.")
    }

    override func setupEdgeConstraint(with height: CGFloat) {
        if #available(iOS 11.0, *) {
            Logger.common(message: "SnackbarViewController setupEdgeConstraint iOS 11+.")
            edgeConstraint = snackbarView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: height)
        } else {
            Logger.common(message: "SnackbarViewController setupEdgeConstraint iOS 10.")
            edgeConstraint = snackbarView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: height)
        }
        
        edgeConstraint?.isActive = true
    }
}
