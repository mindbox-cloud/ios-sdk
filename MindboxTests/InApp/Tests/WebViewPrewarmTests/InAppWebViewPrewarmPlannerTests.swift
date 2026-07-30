//
//  InAppWebViewPrewarmPlannerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("InApp WebView prewarm planning", .tags(.webView))
struct InAppWebViewPrewarmPlannerTests {

    private func webviewLayer(
        baseUrl: String? = "https://inapp.local/popup",
        contentUrl: String? = "https://mobile-static.mindbox.ru/stable/inapps/webview/content/index.html"
    ) -> WebviewContentBackgroundLayerDTO {
        WebviewContentBackgroundLayerDTO(baseUrl: baseUrl, contentUrl: contentUrl, params: nil)
    }

    // MARK: Prewarm source (partition baseURL + contentURL from one layer)

    @Test("Prewarm source is taken from the first fully showable layer")
    func prewarmSourcePicksFirstValid() throws {
        let layers = [
            webviewLayer(baseUrl: nil),
            webviewLayer(baseUrl: "https://inapp.local/popup"),
            webviewLayer(baseUrl: "https://other.example/popup")
        ]
        let source = try #require(InAppWebViewPrewarmPlanner.prewarmSource(for: layers))
        #expect(source.baseURL.absoluteString == "https://inapp.local/popup")
    }

    @Test("No layer with a usable baseUrl yields no prewarm source", arguments: [
        [] as [String?],
        [nil],
        [""]
    ])
    func prewarmSourceMissing(baseUrls: [String?]) {
        let layers = baseUrls.map { webviewLayer(baseUrl: $0) }
        #expect(InAppWebViewPrewarmPlanner.prewarmSource(for: layers) == nil)
    }

    @Test("Host-less baseUrls and layers without contentUrl don't donate a prewarm source")
    func prewarmSourceRequiresHostAndContent() throws {
        let hostless = webviewLayer(baseUrl: "popup")
        let noContent = webviewLayer(contentUrl: nil)
        let valid = webviewLayer()

        let source = try #require(InAppWebViewPrewarmPlanner.prewarmSource(for: [hostless, noContent, valid]))
        #expect(source.baseURL.host == "inapp.local")
        #expect(InAppWebViewPrewarmPlanner.prewarmSource(for: [hostless, noContent]) == nil)
    }

    @Test("Non-https layers never donate a prewarm source")
    func prewarmSourceRequiresHttps() throws {
        let httpBase = webviewLayer(baseUrl: "http://insecure.local/popup")
        let httpContent = webviewLayer(contentUrl: "http://cdn.example/index.html")
        let valid = webviewLayer()

        #expect(InAppWebViewPrewarmPlanner.prewarmSource(for: [httpBase, httpContent]) == nil)
        let source = try #require(InAppWebViewPrewarmPlanner.prewarmSource(for: [httpBase, httpContent, valid]))
        #expect(source.baseURL.host == "inapp.local")
    }

    @Test("Base and content URLs always come from the same layer — never mixed across layers")
    func prewarmSourceNeverMixesLayers() throws {
        let broken = webviewLayer(baseUrl: "not a url", contentUrl: "https://cdn.a/index.html")
        let valid = webviewLayer(baseUrl: "https://inapp.local/popup", contentUrl: "https://cdn.b/index.html")

        let source = try #require(InAppWebViewPrewarmPlanner.prewarmSource(for: [broken, valid]))
        #expect(source.baseURL.host == "inapp.local")
        #expect(source.contentURL.absoluteString == "https://cdn.b/index.html")
    }

    // MARK: Preconnect hosts

    @Test("Hosts are deduplicated, merged with API domain and learned hosts, and sorted")
    func preconnectHostsMergesAllSources() {
        let layers = [
            webviewLayer(contentUrl: "https://mobile-static.mindbox.ru/a/index.html"),
            webviewLayer(contentUrl: "https://mobile-static.mindbox.ru/b/index.html")
        ]
        let hosts = InAppWebViewPrewarmPlanner.preconnectHosts(
            layers: layers,
            apiDomain: "api.mindbox.ru",
            learnedHosts: ["web-static.mindbox.ru", "api.mindbox.ru"]
        )
        #expect(hosts == ["api.mindbox.ru", "mobile-static.mindbox.ru", "web-static.mindbox.ru"])
    }

    @Test("Invalid content URLs and an absent API domain contribute nothing")
    func preconnectHostsSkipsUnusableSources() {
        let layers = [webviewLayer(contentUrl: nil), webviewLayer(contentUrl: "")]
        let hosts = InAppWebViewPrewarmPlanner.preconnectHosts(layers: layers, apiDomain: nil, learnedHosts: [])
        #expect(hosts.isEmpty)

        let emptyDomain = InAppWebViewPrewarmPlanner.preconnectHosts(layers: layers, apiDomain: "", learnedHosts: [])
        #expect(emptyDomain.isEmpty)
    }

    // MARK: Preconnect page

    @Test("Preconnect page hints every host and downloads nothing")
    func preconnectHTMLContainsHints() {
        let html = InAppWebViewPrewarmPlanner.preconnectHTML(hosts: ["a.example", "b.example"])
        #expect(html.contains("<link rel=\"preconnect\" href=\"https://a.example\" crossorigin>"))
        #expect(html.contains("<link rel=\"dns-prefetch\" href=\"https://b.example\">"))
        #expect(!html.contains("<script"))
        #expect(!html.contains("<img"))
    }

    @Test("Every host is re-validated at the markup choke point")
    func preconnectHTMLRejectsNonHostValues() {
        let html = InAppWebViewPrewarmPlanner.preconnectHTML(
            hosts: ["ok.example", "evil\"><script>alert(1)</script>", "spaced host.ru"]
        )
        #expect(html.contains("https://ok.example"))
        #expect(!html.contains("<script"))
        #expect(!html.contains("spaced host.ru"))
    }

    @Test("Host validation accepts bare hosts only", arguments: zip(
        ["cdn.mindbox.ru", "evil.com:443", "user@evil.com", "evil.com?x=1", "host with space", "",
         "a&b.com", "a'b.com", "a;b.com", "a=b.com", "a_b.com", "(evil).com", "host.ru.",
         String(repeating: "a", count: 300) + ".com"],
        [true, false, false, false, false, false,
         false, false, false, false, false, false, false,
         false]
    ))
    func isValidHost(candidate: String, expected: Bool) {
        #expect(InAppWebViewPrewarmPlanner.isValidHost(candidate) == expected)
    }

    // MARK: Prewarm content baseURL (official web prewarm contract)

    @Test("Prewarm content baseURL carries the official prewarm query parameters")
    func prewarmContentBaseURLAppendsContract() throws {
        let baseURL = try #require(URL(string: "https://inapp.local/popup"))

        let url = InAppWebViewPrewarmPlanner.prewarmContentBaseURL(
            from: baseURL, endpoint: "Mpush-test.WebView", deviceUUID: "abc-123"
        )

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "inapp.local")
        #expect(components.path == "/popup")
        let query = try #require(components.queryItems)
        #expect(query.contains(URLQueryItem(name: "prewarm", value: "1")))
        #expect(query.contains(URLQueryItem(name: "endpointId", value: "Mpush-test.WebView")))
        #expect(query.contains(URLQueryItem(name: "deviceUuid", value: "abc-123")))
    }

    @Test("Existing baseURL query survives and unsafe values are percent-encoded")
    func prewarmContentBaseURLKeepsQueryAndEncodes() throws {
        let baseURL = try #require(URL(string: "https://inapp.local/popup?keep=me"))

        let url = InAppWebViewPrewarmPlanner.prewarmContentBaseURL(
            from: baseURL, endpoint: "End point&x", deviceUUID: "uuid"
        )

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = try #require(components.queryItems)
        #expect(query.contains(URLQueryItem(name: "keep", value: "me")))
        #expect(query.contains(URLQueryItem(name: "endpointId", value: "End point&x")))
        #expect(url.absoluteString.contains("endpointId=End%20point%26x"))
    }

    @Test("Parameters land in the query, not the fragment")
    func prewarmContentBaseURLKeepsFragmentSeparate() throws {
        // In the fragment they would be invisible to location.search and the contract
        // would silently degrade to a plain page warm.
        let baseURL = try #require(URL(string: "https://inapp.local/popup#main"))

        let url = InAppWebViewPrewarmPlanner.prewarmContentBaseURL(
            from: baseURL, endpoint: "E", deviceUUID: "d"
        )

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.fragment == "main")
        let query = try #require(components.queryItems)
        #expect(query.contains(URLQueryItem(name: "prewarm", value: "1")))
    }

    // MARK: Layer extraction from a parsed config

    @Test("Webview layers and prewarm inputs are extracted from a parsed config")
    func extractsLayersFromParsedConfig() throws {
        let config = try loadPrewarmTestConfig("InAppWebviewValid")

        let layers = InAppWebViewPrewarmPlanner.webviewLayers(in: config)

        let source = try #require(InAppWebViewPrewarmPlanner.prewarmSource(for: layers))
        #expect(source.baseURL.host == "inapp.local")

        let hosts = InAppWebViewPrewarmPlanner.preconnectHosts(layers: layers, apiDomain: "api.mindbox.ru", learnedHosts: [])
        let contentUrl = try #require(layers.first?.contentUrl)
        let contentHost = try #require(URL(string: contentUrl)?.host)
        #expect(hosts.contains("api.mindbox.ru"))
        #expect(hosts.contains(contentHost))
    }

    @Test("Configs without webview layers plan nothing", arguments: [
        "InAppLayerUnknownType", "InAppFormVariantUnknownType"
    ])
    func noWebviewLayersInNonWebviewConfig(fixture: String) throws {
        let config = try loadPrewarmTestConfig(fixture)
        #expect(InAppWebViewPrewarmPlanner.webviewLayers(in: config).isEmpty)
    }
}

func loadPrewarmTestConfig(_ name: String) throws -> ConfigResponse {
    let bundle = Bundle(for: MindboxTests.self)
    let url = try #require(bundle.url(forResource: name, withExtension: "json"))
    return try JSONDecoder().decode(ConfigResponse.self, from: Data(contentsOf: url))
}
