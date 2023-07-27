//
//  InAppMessageViewController.swift
//  Mindbox
//
//  Created by Максим Казаков on 07.09.2022.
//

import UIKit

final class InAppMessageViewController: UIViewController {
    
    var crossView: CrossView?
    var inAppView: InAppImageOnlyView?
    var crossSize: CGFloat = 24

    init(
        inAppUIModel: InAppMessageUIModel,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.inAppUIModel = inAppUIModel
        self.onPresented = onPresented
        self.onClose = onClose
        self.onTapAction = onTapAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let inAppUIModel: InAppMessageUIModel
    private let onPresented: () -> Void
    private let onClose: () -> Void
    private let onTapAction: () -> Void

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black.withAlphaComponent(0.2)
        
        inAppView = InAppImageOnlyView(uiModel: inAppUIModel)
        crossView = CrossView(lineColorHex: "000000", lineWidth: 1)
        
        guard let inAppView = inAppView,
              let crossView = crossView else {
            return
        }
        let onTapDimmedViewGesture = UITapGestureRecognizer(target: self, action: #selector(onTapDimmedView))
        view.addGestureRecognizer(onTapDimmedViewGesture)
        view.isUserInteractionEnabled = true
        view.addSubview(inAppView)
        
        inAppView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inAppView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            inAppView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            inAppView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            inAppView.widthAnchor.constraint(equalTo: inAppView.heightAnchor, multiplier: 3 / 4)
        ])
        let imageTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onTapImage))
        inAppView.addGestureRecognizer(imageTapGestureRecognizer)

        inAppView.addSubview(crossView)
        crossView.isUserInteractionEnabled = true

        let closeRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(onCloseButton))
        closeRecognizer.minimumPressDuration = 0
        crossView.addGestureRecognizer(closeRecognizer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard let inAppView = inAppView,
              let crossView = crossView else {
            return
        }
        
        let trailingOffsetPercent: CGFloat = 0.03
        let topOffsetPercent: CGFloat = 0.03

        let horizontalOffset = (inAppView.frame.width - crossSize) * trailingOffsetPercent
        let verticalOffset = (inAppView.frame.height - crossSize) * topOffsetPercent
        crossView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            crossView.trailingAnchor.constraint(equalTo: inAppView.trailingAnchor, constant: -horizontalOffset),
            crossView.topAnchor.constraint(equalTo: inAppView.topAnchor, constant: verticalOffset),
            crossView.widthAnchor.constraint(equalToConstant: crossSize),
            crossView.heightAnchor.constraint(equalToConstant: crossSize)
        ])
    }

    private var viewWillAppearWasCalled = false
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !viewWillAppearWasCalled else { return }
        viewWillAppearWasCalled = true
        onPresented()
    }

    @objc private func onCloseButton(_ gesture: UILongPressGestureRecognizer) {
        guard let crossView = crossView else {
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

    @objc private func onTapImage() {
        onTapAction()
    }
}
