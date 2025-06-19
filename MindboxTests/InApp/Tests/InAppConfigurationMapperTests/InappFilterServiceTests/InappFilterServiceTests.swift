//
//  InappFilterServiceTests.swift
//  MindboxTests
//
//  Created by vailence on 14.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable force_unwrapping

final class InappFilterServiceTests: XCTestCase {

    enum Constants {
        static let defaultID = "5696ac18-70cb-496f-80c5-a47eb7573df7"
        static let defaultColor = "#FFFFFF"
        static let defaultLineWidth = 2
        static let defaultSize: Double = 24
    }

    var sut: InappsFilterService!

    override func setUp() {
        super.setUp()
        sut = DI.injectOrFail(InappFilterProtocol.self) as? InappsFilterService
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_unknown_type_for_variants() throws {
        let config = try getConfig(name: "unknownVariantType")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_missingBackgroundSection() throws {
        let config = try getConfig(name: "missingBackgroundSection")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_emptyLayersSection() throws {
        let config = try getConfig(name: "emptyLayersSection")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_unknownLayerType() throws {
        let config = try getConfig(name: "unknownLayerType")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_knownImageUnknownPictureLayerType() throws {
        let config = try getConfig(name: "knownImageUnknownPictureLayerType")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 2)

        if let variant = inapps.first?.form.variants.first {
            switch variant {

                case .modal(let model):
                    XCTAssertEqual(model.content.background.layers.count, 1)
                default:
                    break
            }
        }
    }

    func test_unknownActionLayerType() throws {
        let config = try getConfig(name: "unknownActionLayerType")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_redirectUrlValueNumberInsteadOfString() throws {
        let config = try getConfig(name: "redirectUrlValueNumberInsteadOfString")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_missingIntentPayloadInActionLayer() throws {
        let config = try getConfig(name: "missingIntentPayloadInActionLayer")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_missingSourceSection() throws {
        let config = try getConfig(name: "missingSourceSection")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_emptyVariantsArray() throws {
        let config = try getConfig(name: "emptyVariantsArray")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_unknownSourceType() throws {
        let config = try getConfig(name: "unknownSourceType")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_missingValueInSourceLayer() throws {
        let config = try getConfig(name: "missingValueInSourceLayer")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_missingImageLinkInSourceLayerValue() throws {
        let config = try getConfig(name: "missingImageLinkInSourceLayerValue")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_missingElementsSection() throws {
        let config = try getConfig(name: "missingElementsSection")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 2)

        if let variant = inapps.first?.form.variants.first {
            switch variant {

                case .modal(let model):
                    XCTAssertEqual(model.content.elements?.count, 0)
                default:
                    break
            }
        }
    }

    func test_invalidCloseButtonColor() throws {
        let config = try getConfig(name: "invalidCloseButtonColor")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 2)

        if let variant = inapps.first?.form.variants.first {
            switch variant {
                case .modal(let model):
                    guard let type = model.content.elements?.first else {
                        assertionFailure("type not exists. ")
                        return
                    }
                    switch type {
                        case .closeButton(let model):
                            XCTAssertEqual(model.color, Constants.defaultColor)
                        default:
                            break
                    }
                default:
                    break
            }
        }
    }

    func test_missingCloseButtonColorLineWidthSize() throws {
        let config = try getConfig(name: "missingCloseButtonColorLineWidthSize")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 2)

        if let variant = inapps.first?.form.variants.first {
            switch variant {
                case .modal(let model):
                    guard let type = model.content.elements?.first else {
                        assertionFailure("type not exists.")
                        return
                    }
                    switch type {
                        case .closeButton(let model):
                            XCTAssertEqual(model.color, Constants.defaultColor)
                            XCTAssertEqual(model.size.height, Constants.defaultSize)
                            XCTAssertEqual(model.size.width, Constants.defaultSize)
                            XCTAssertEqual(model.lineWidth, Constants.defaultLineWidth)
                        default:
                            break
                    }
                default:
                    break
            }
        }
    }

    func test_twoCloseButtonsInApp() throws {
        let config = try getConfig(name: "twoCloseButtonsInApp")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 2)

        if let variant = inapps.first?.form.variants.first {
            switch variant {
                case .modal(let model):
                    guard let elements = model.content.elements else {
                        assertionFailure("elements not exists.")
                        return
                    }

                    var counter = 0
                    elements.forEach {
                        counter += $0.elementType == .closeButton ? 1 : 0
                    }

                    XCTAssertEqual(counter, 2)
                default:
                    break
            }
        }
    }

    func test_closeButtonWithOpenButton() throws {
        let config = try getConfig(name: "closeButtonWithOpenButton")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 2)

        if let variant = inapps.first?.form.variants.first {
            switch variant {
                case .modal(let model):
                    guard let elements = model.content.elements else {
                        assertionFailure("elements not exists.")
                        return
                    }

                    XCTAssertEqual(elements.count, 1)
                    switch elements.first! {
                        case .closeButton:
                            XCTAssertTrue(true)
                            return
                        default:
                            break
                    }
                default:
                    break
            }
        }

        assertionFailure()
    }

    func test_unknownSizeKind() throws {
        let config = try getConfig(name: "unknownSizeKind")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 2)

        if let variant = inapps.first?.form.variants.first {
            switch variant {
                case .modal(let model):
                    guard let elements = model.content.elements else {
                        assertionFailure("elements not exists.")
                        return
                    }

                    XCTAssertEqual(elements.count, 1)
                    switch elements.first! {
                        case .closeButton(let model):
                            XCTAssertEqual(model.size.kind, .dp)
                            XCTAssertEqual(model.size.width, Constants.defaultSize)
                            XCTAssertEqual(model.size.height, Constants.defaultSize)
                            return
                        default:
                            break
                    }
                default:
                    break
            }
        }

        assertionFailure()
    }

    func test_missingMarginFieldInSection() throws {
        let config = try getConfig(name: "missingMarginFieldInSection")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_negativeCloseButtonSizeValues() throws {
        let config = try getConfig(name: "negativeCloseButtonSizeValues")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_closeButtonMarginAboveOne() throws {
        let config = try getConfig(name: "closeButtonMarginAboveOne")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_closeButtonMarginBelowZero() throws {
        let config = try getConfig(name: "closeButtonMarginBelowZero")
        let inapps = sut.filter(inapps: config.inapps?.elements, abTests: config.abtests)
        XCTAssertEqual(inapps.count, 1)
        XCTAssertEqual(inapps.first?.id, Constants.defaultID)
    }

    func test_sortInappsByPriority_maintainsOrderForSamePriority() {
        let inapps = [
            createTestInApp(id: "1", isPriority: true),
            createTestInApp(id: "2", isPriority: false),
            createTestInApp(id: "3", isPriority: true),
            createTestInApp(id: "4", isPriority: true),
            createTestInApp(id: "5", isPriority: false)
        ]
        
        let sortedInapps = sut.sortInappsByPriority(inapps)
        
        // Then: Priority in-apps should come first, maintaining original order within same priority
        let expectedOrder = ["1", "3", "4", "2", "5"]
        let actualOrder = sortedInapps.map { $0.id }
        
        XCTAssertEqual(actualOrder, expectedOrder, "In-apps should be sorted by priority with true values first, maintaining original order within same priority")
        
        XCTAssertTrue(sortedInapps[0].isPriority)
        XCTAssertTrue(sortedInapps[1].isPriority)
        XCTAssertTrue(sortedInapps[2].isPriority)
        XCTAssertFalse(sortedInapps[3].isPriority)
        XCTAssertFalse(sortedInapps[4].isPriority)
    }
    
    func test_sortInappsByPriority_allTruePriority() {
        let inapps = [
            createTestInApp(id: "1", isPriority: true),
            createTestInApp(id: "2", isPriority: true),
            createTestInApp(id: "3", isPriority: true)
        ]
        
        let sortedInapps = sut.sortInappsByPriority(inapps)
        
        // Then: Order should remain the same
        let expectedOrder = ["1", "2", "3"]
        let actualOrder = sortedInapps.map { $0.id }
        
        XCTAssertEqual(actualOrder, expectedOrder, "Order should remain unchanged when all in-apps have same priority")
    }
    
    func test_sortInappsByPriority_allFalsePriority() {
        let inapps = [
            createTestInApp(id: "1", isPriority: false),
            createTestInApp(id: "2", isPriority: false),
            createTestInApp(id: "3", isPriority: false)
        ]
        
        let sortedInapps = sut.sortInappsByPriority(inapps)
        
        // Then: Order should remain the same
        let expectedOrder = ["1", "2", "3"]
        let actualOrder = sortedInapps.map { $0.id }
        
        XCTAssertEqual(actualOrder, expectedOrder, "Order should remain unchanged when all in-apps have same priority")
    }

    // MARK: - Helper Methods
    
    private func createTestInApp(id: String, isPriority: Bool) -> InApp {
        let sdkVersion = SdkVersion(min: 8, max: nil)
        let targeting = TrueTargeting()
        let frequency = InappFrequency.once(OnceFrequency(kind: .session))
        let form = InAppForm(variants: [])
        
        return InApp(
            id: id,
            isPriority: isPriority,
            sdkVersion: sdkVersion,
            targeting: .true(targeting),
            frequency: frequency,
            form: form
        )
    }

    private func getConfig(name: String) throws -> ConfigResponse {
        let bundle = Bundle(for: InappFilterServiceTests.self)
        let fileURL = bundle.url(forResource: name, withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ConfigResponse.self, from: data)
    }
}
