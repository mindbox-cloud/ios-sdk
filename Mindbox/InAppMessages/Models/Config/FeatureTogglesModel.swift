//
//  FeatureTogglesModel.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.02.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

extension Settings {
    struct FeatureToggles: Decodable, Equatable {
        let shouldSendInAppShowError: Bool?
        let shouldPrewarmInAppWebView: Bool?
        let shouldCacheInAppWebView: Bool?

        enum CodingKeys: String, CodingKey {
            case shouldSendInAppShowError = "MobileSdkShouldSendInAppShowError"
            case shouldPrewarmInAppWebView = "MobileSdkShouldPrewarmInAppWebView"
            case shouldCacheInAppWebView = "MobileSdkShouldCacheInAppWebView"
        }
    }
}

extension Settings.FeatureToggles {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.shouldSendInAppShowError = try? container.decodeIfPresent(Bool.self, forKey: .shouldSendInAppShowError)
        self.shouldPrewarmInAppWebView = try? container.decodeIfPresent(Bool.self, forKey: .shouldPrewarmInAppWebView)
        self.shouldCacheInAppWebView = try? container.decodeIfPresent(Bool.self, forKey: .shouldCacheInAppWebView)
    }
}
