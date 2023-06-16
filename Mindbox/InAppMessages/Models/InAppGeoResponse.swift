//
//  InAppGeoResponse.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//

import Foundation

struct InAppGeoResponse: Codable, Equatable {
    let city: Int
    let region: Int
    let country: Int

    enum CodingKeys: String, CodingKey {
        case city = "city_id"
        case region = "region_id"
        case country = "country_id"
    }
}

struct FetchInAppGeoRoute: Route {
    
    var method: HTTPMethod { .get }

    var path: String { "/geo" }

    var headers: HTTPHeaders? { nil }

    var queryParameters: QueryParameters { .init() }

    var body: Data? { nil }
}
