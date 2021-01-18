//
//  BaseResponse.swift
//  MindBox
//
//  Created by Mikhail Barilov on 18.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

import Foundation


class BaseResponce: Codable {
    //    response StatusCode
    var responseStatusCode: Int?
    //    "InternalServerError",
    var status: StatusCode
    //    <http-код ошибки (число)>
    var httpStatusCode: Int?
}

class ResponseModel<T: Codable>: BaseResponce {

    // MARK: - Properties

    var rawData: Data?
    var data: T?
    var json: String? {
        guard let rawData = rawData else { return nil }
        return String(data: rawData, encoding: String.Encoding.utf8)
    }
    var request: RequestModel?

    // MARK: - Init

    required public init(from decoder: Decoder) throws {
        let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
        data = try? keyedContainer.decode(T.self, forKey: CodingKeys.data)
        try super.init(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case data
    }
}
