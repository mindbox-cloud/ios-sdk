//
//  ModalViewController.swift
//  Mindbox
//
//  Created by Максим Казаков on 07.09.2022.
//

import UIKit

protocol InappViewControllerProtocol {
    var layers: [UIView] { get set }
    var elements: [UIView] { get set }
    var elementFactories: [ContentElementType: ElementFactory] { get }
    var layersFactories: [ContentBackgroundLayerType: LayerFactory] { get }
}

@objc protocol GestureHandler {
    @objc func imageTapped(_ sender: UITapGestureRecognizer)
    @objc func onCloseButton(_ gesture: UILongPressGestureRecognizer)
}

final class ModalViewController: UIViewController, InappViewControllerProtocol, GestureHandler {
    
    var layers = [UIView]()
    var elements = [UIView]()
    let elementFactories: [ContentElementType: ElementFactory] = [
        .closeButton: CloseButtonElementFactory()
    ]
    
    let layersFactories: [ContentBackgroundLayerType: LayerFactory] = [
        .image: ImageLayerFactory()
    ]

    init(
        model: ModalFormVariant,
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

    private let model: ModalFormVariant
    private let id: String
    private let imagesDict: [String: UIImage]
    private let onPresented: () -> Void
    private let onClose: () -> Void
    private let onTapAction: (ContentBackgroundLayerAction?) -> Void

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black.withAlphaComponent(0.2)
        let onTapDimmedViewGesture = UITapGestureRecognizer(target: self, action: #selector(onTapDimmedView))
        view.addGestureRecognizer(onTapDimmedViewGesture)
        view.isUserInteractionEnabled = true
        
        setupLayers()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupElements()
    }

    private var viewWillAppearWasCalled = false
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !viewWillAppearWasCalled else { return }
        viewWillAppearWasCalled = true
        onPresented()
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

    @objc private func onTapDimmedView() {
        onClose()
    }

    @objc func imageTapped(_ sender: UITapGestureRecognizer) {
        guard let imageView = sender.view as? InAppImageOnlyView else {
            return
        }
        
        let action = imageView.action
        onTapAction(action)
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
                            view.addSubview(layerView)
                            factory.setupConstraints(for: layerView, in: view)
                        }
                    }
                }
            }
        }
    }
    
    private func setupElements() {
        guard let elements = model.content.elements,
              let inappView = layers.first(where: { $0 is InAppImageOnlyView }) else {
            return
        }

        for element in elements {
            if let factory = elementFactories[element.elementType] {
                let elementView = factory.create(from: element, with: self)
                if let elementView = elementView {
                    self.elements.append(elementView)
                    view.addSubview(elementView)
                    factory.setupConstraints(for: elementView, from: element, in: inappView)
                }
            }
        }
    }
}
