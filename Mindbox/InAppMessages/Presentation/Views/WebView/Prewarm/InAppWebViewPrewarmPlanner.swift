//
//  InAppWebViewPrewarmPlanner.swift
//  Mindbox
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum InAppWebViewPrewarmPlanner {

    static func prewarmSource(for layers: [WebviewContentBackgroundLayerDTO]) -> (baseURL: URL, contentURL: URL)? {
        for layer in layers {
            guard let baseURL = layer.baseUrl.flatMap(URL.init(string:)),
                  baseURL.scheme?.lowercased() == "https", baseURL.host != nil,
                  let contentURL = layer.contentUrl.flatMap(URL.init(string:)),
                  contentURL.scheme?.lowercased() == "https" else { continue }
            return (baseURL, contentURL)
        }
        return nil
    }

    static func preconnectHosts(layers: [WebviewContentBackgroundLayerDTO],
                                apiDomain: String?,
                                learnedHosts: [String]) -> [String] {
        var hosts = Set(layers.compactMap { layer -> String? in
            guard let contentUrl = layer.contentUrl, let host = URL(string: contentUrl)?.host else { return nil }
            return host
        })
        if let apiDomain, !apiDomain.isEmpty {
            hosts.insert(apiDomain)
        }
        hosts.formUnion(learnedHosts)
        return hosts.sorted()
    }

    static func preconnectHTML(hosts: [String]) -> String {
        let links = hosts
            .filter(isValidHost)
            .map { "<link rel=\"preconnect\" href=\"https://\($0)\" crossorigin><link rel=\"dns-prefetch\" href=\"https://\($0)\">" }
            .joined()
        return "<html><head><meta charset=\"utf-8\">\(links)</head><body></body></html>"
    }

    static func isValidHost(_ host: String) -> Bool {
        URLValidator.isValidHost(host)
    }

    /// The official prewarm contract with the web runtime: the prewarm content page is
    /// loaded with these parameters on its document URL (`loadHTMLString` baseURL →
    /// `location.search`), and a runtime that knows the contract boots tracker-only —
    /// no `ready` handshake, no form, byendpoint straight into the HTTP cache. Older
    /// runtimes ignore the parameters (plain page warm). Shows never get these parameters.
    static func prewarmContentBaseURL(from baseURL: URL, endpoint: String, deviceUUID: String) -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return baseURL }
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "prewarm", value: "1"))
        queryItems.append(URLQueryItem(name: "endpointId", value: endpoint))
        queryItems.append(URLQueryItem(name: "deviceUuid", value: deviceUUID))
        components.queryItems = queryItems
        return components.url ?? baseURL
    }

    static func webviewLayers(in config: ConfigResponse) -> [WebviewContentBackgroundLayerDTO] {
        var result: [WebviewContentBackgroundLayerDTO] = []
        for inapp in config.inapps?.elements ?? [] {
            for variant in inapp.form.variants ?? [] {
                let layers: [ContentBackgroundLayerDTO]?
                switch variant {
                case .modal(let modal): layers = modal.content?.background?.layers
                case .snackbar(let snackbar): layers = snackbar.content?.background?.layers
                case .embedded: layers = nil
                case .unknown: layers = nil
                }
                for layer in layers ?? [] {
                    if case .webview(let webview) = layer {
                        result.append(webview)
                    }
                }
            }
        }
        return result
    }

    static let observedHostsScript = """
    Array.from(new Set(performance.getEntriesByType('resource').map(function (r) {
      try { var u = new URL(r.name); return u.protocol === 'https:' ? u.host : null } catch (e) { return null }
    }).filter(Boolean)))
    """
}
