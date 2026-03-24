//
//  Tag+Extensions.swift
//  MindboxTests
//
//  Created by vailence on 29.11.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import Testing

extension Tag {
    @Tag static var sdkVersion: Self
    @Tag static var customOperation: Self
    @Tag static var category: Self
    @Tag static var product: Self
    @Tag static var productSegment: Self
    
    @Tag static var decoding: Self
    
    @Tag static var inAppSchedule: Self
    
    @Tag static var remainingTargeting: Self
    @Tag static var abTesting: Self
    @Tag static var geoTargeting: Self
    @Tag static var webView: Self
    @Tag static var trackVisit: Self
}
