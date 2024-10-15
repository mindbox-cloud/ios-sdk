//
//  TrackVisit.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

struct TrackVisit: Codable {
    /// ID текущая таймзона устройства в формате IANA, например "Asia/Krasnoyarsk", null если недоступно
    let ianaTimeZone: String?

    /// ссылка, по которой перешли в приложение, либо null
    let requestUrl: URL?

    let source: TrackVisitSource?

    let sdkVersionNumeric: Int

    init(url: URL? = nil, source: TrackVisitSource? = nil) {
        requestUrl = url
        self.source = source
        ianaTimeZone = TimeZone.current.identifier
        self.sdkVersionNumeric = Constants.Versions.sdkVersionNumeric
    }
}

enum TrackVisitSource: String, Codable {
    case direct, link, push
}
