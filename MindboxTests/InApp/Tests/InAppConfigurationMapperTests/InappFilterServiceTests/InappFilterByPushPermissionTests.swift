//
//  InappFilterByPushPermissionTests.swift
//  MindboxTests
//
//  Created by vailence on 18.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class InappFilterByPushPermissionTests: XCTestCase {
    
    var sut: InappFilterByPushPermissionProtocol!
    var container: TestDependencyProvider!
    
    override func setUp() {
        super.setUp()
        container = try! TestDependencyProvider()
        sut = container.pushPermissionFilterService
    }
    
    override func tearDown() {
        sut = nil
        SessionTemporaryStorage.shared.erase()
        super.tearDown()
    }
    
    func test_1Inapp_PushPermission_notDetermined_or_denied() throws {
        for status in [UNAuthorizationStatus.notDetermined, UNAuthorizationStatus.denied] {
            let variant = try getVariant()
            SessionTemporaryStorage.shared.pushPermissionStatus = status
            XCTAssertTrue(self.sut.checkPushPermissionConditionPassed(from: variant), "Check failed with status \(status) and variant: \(variant)")
        }
    }
    
    func test_1Inapp_PushPermission_authorized() throws {
        if #available(iOS 14.0, *) {
            for status in [UNAuthorizationStatus.authorized, .provisional, .ephemeral] {
                let variant = try getVariant()
                SessionTemporaryStorage.shared.pushPermissionStatus = status
                XCTAssertFalse(self.sut.checkPushPermissionConditionPassed(from: variant), "Check failed with status \(status) and variant: \(variant)")
            }
        }
    }
    
    private func getVariant() throws -> MindboxFormVariant {
        let source = try ContentBackgroundLayerSource(type: .url, urlModel: .init(value: "https://google.com"))
        let imageLayer = ImageContentBackgroundLayer(action: .pushPermission(PushPermissionLayerAction(intentPayload: "test_payload")),
                                                     source: source)
        let layer = try ContentBackgroundLayer(type: .image, imageLayer: imageLayer)
        let background = ContentBackground(layers: [layer])
        let content = InappFormVariantContent(background: background, elements: [])
        let modalVariant = ModalFormVariant(content: content)
        let variant = try MindboxFormVariant(type: .modal, modalVariant: modalVariant)
        return variant
    }
}
