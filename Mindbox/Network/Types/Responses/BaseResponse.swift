//
//  BaseResponse.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 18.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

import Foundation

class BaseResponse: Codable {
    
    struct ValidationMessage: Codable {
        // "<текст ошибки>",
        var message: String
        // "<адрес поля с ошибкой>"
        var location: String
    }
    
    //    response StatusCode
    var responseStatusCode: Int?
    //    "InternalServerError",
    var status: StatusCode = .unknow
    //    <http-код ошибки (число)>
    var httpStatusCode: Int?
    
    var validationMessages: [ValidationMessage]?
    //    "<сообщение об ошибке>",
    var errorMessage: String?
    //    "<uuid  ошибки>",
    var errorId: String?

}

class ResponseModel<T: Codable> {

    // MARK: - Properties

    var rawData: Data?
    var data: T?
    var json: String? {
        guard let rawData = rawData else { return nil }
        return String(data: rawData, encoding: String.Encoding.utf8)
    }
    var route: Route?

    // MARK: - Init

    required public init()  {

    }

    private enum CodingKeys: String, CodingKey {
        case data
    }
}
