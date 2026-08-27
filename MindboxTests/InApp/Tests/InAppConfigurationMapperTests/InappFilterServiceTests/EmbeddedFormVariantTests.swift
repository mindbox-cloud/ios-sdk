//
//  EmbeddedFormVariantTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("Embedded form variant filtering", .tags(.embeddedBlocks))
struct EmbeddedFormVariantTests {

    private let sut = DI.injectOrFail(VariantFilterProtocol.self)

    private func webviewLayer(contentUrl: String = "https://mobile-static-staging.mindbox.ru/inapps/webview/content/stories.html") -> String {
        """
        {
          "$type": "webview",
          "baseUrl": "https://inapp.local/stories",
          "contentUrl": "\(contentUrl)",
          "params": { "stories": [] }
        }
        """
    }

    private func embeddedVariant(place: String?, layers: String? = nil) -> String {
        let placeField = place.map { "\"placeSystemName\": \"\($0)\"," } ?? ""
        return """
        {
          \(placeField)
          "$type": "embedded",
          "content": {
            "background": { "layers": [\(layers ?? webviewLayer())] },
            "elements": null
          }
        }
        """
    }

    private func filter(_ variants: String...) throws -> [MindboxFormVariant] {
        let json = "[\(variants.joined(separator: ","))]"
        let dtos = try JSONDecoder().decode([MindboxFormVariantDTO].self, from: Data(json.utf8))
        return try sut.filter(dtos)
    }

    private func place(of variant: MindboxFormVariant?) -> String? {
        guard case .embedded(let embedded) = variant else { return nil }
        return embedded.placeSystemName
    }

    @Test("A webview layer and a place name make a usable variant")
    func validVariant() throws {
        let variants = try filter(embeddedVariant(place: "stories-list-container"))
        #expect(variants.count == 1)
        #expect(place(of: variants.first) == "stories-list-container")
    }

    /// The name travels through JSON, so the escaped case arrives with a real newline and tab —
    /// hence the expected value next to each input.
    @Test("Place name keeps whatever padding it came with", arguments: [
        ("  stories-list-container", "  stories-list-container"),
        ("stories-list-container  ", "stories-list-container  "),
        (#"\n stories-list-container \t"#, "\n stories-list-container \t")
    ])
    func keepsPlaceNamePadding(place: String, expected: String) throws {
        let variants = try filter(embeddedVariant(place: place))
        #expect(self.place(of: variants.first) == expected)
    }

    @Test("Place name case is preserved")
    func keepsPlaceNameCase() throws {
        let variants = try filter(embeddedVariant(place: "Stories-List-Container"))
        #expect(place(of: variants.first) == "Stories-List-Container")
    }

    @Test("A variant that cannot address a block is dropped", arguments: [
        nil, ""
    ] as [String?])
    func dropsVariantWithoutPlace(place: String?) throws {
        #expect(try filter(embeddedVariant(place: place)).isEmpty)
    }

    @Test("A variant with no webview layer is dropped", arguments: [
        "",
        #"{"$type": "image", "source": {"$type": "url", "value": "https://example.com/a.png"}, "action": {"$type": "redirectUrl", "intentPayload": "payload", "value": "https://example.com"}}"#
    ])
    func dropsVariantWithoutWebviewLayer(layers: String) throws {
        #expect(try filter(embeddedVariant(place: "stories-list-container", layers: layers)).isEmpty)
    }

    /// A configuration mistake, not a reason to show nothing: the first webview layer wins, in sync with Android.
    @Test("Two webview layers keep the variant and use the first")
    func keepsVariantWithTwoLayersAndUsesTheFirst() throws {
        let first = webviewLayer(contentUrl: "https://example.com/first.html")
        let second = webviewLayer(contentUrl: "https://example.com/second.html")

        let variants = try filter(embeddedVariant(place: "stories-list-container", layers: "\(first),\(second)"))

        let embedded = try #require(variants.first)
        guard case .embedded(let variant) = embedded,
              case .webview(let layer)? = variant.content.background.layers.first else {
            Issue.record("The variant is expected to carry exactly one webview layer")
            return
        }

        #expect(variant.content.background.layers.count == 1)
        #expect(layer.contentUrl == "https://example.com/first.html")
    }

    @Test("A webview layer behind another layer is still found")
    func findsWebviewLayerBehindAnother() throws {
        let image = #"{"$type": "image", "source": {"$type": "url", "value": "https://example.com/a.png"}, "action": {"$type": "redirectUrl", "intentPayload": "payload", "value": "https://example.com"}}"#
        let webview = webviewLayer(contentUrl: "https://example.com/behind.html")

        let variants = try filter(embeddedVariant(place: "stories-list-container", layers: "\(image),\(webview)"))

        let embedded = try #require(variants.first)
        guard case .embedded(let variant) = embedded,
              case .webview(let layer)? = variant.content.background.layers.first else {
            Issue.record("The variant is expected to keep its webview layer")
            return
        }

        #expect(variant.content.background.layers.count == 1)
        #expect(layer.contentUrl == "https://example.com/behind.html")
    }

    @Test("A broken embedded variant does not take its siblings down")
    func keepsSiblingVariants() throws {
        let modal = """
        {
          "$type": "modal",
          "content": {
            "background": { "layers": [\(webviewLayer())] },
            "elements": null
          }
        }
        """

        let variants = try filter(embeddedVariant(place: nil), modal)

        #expect(variants.count == 1)
        // `MindboxFormVariant.==` only compares the case — an expected variant built from content would assert nothing.
        guard case .modal(let survivor)? = variants.first else {
            Issue.record("The modal sibling is expected to survive")
            return
        }

        #expect(survivor.content.background.layers.count == 1)
    }
}
