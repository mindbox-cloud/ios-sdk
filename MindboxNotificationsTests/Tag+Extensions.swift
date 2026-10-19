//
//  Tag+Extensions.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 6/16/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing

extension Tag {
    @Tag static var notifications: Self

    // MARK: Subject areas

    @Tag static var pushParsing: Self

    @Tag static var imageFormat: Self

    @Tag static var notificationService: Self

    @Tag static var notificationContent: Self
}
