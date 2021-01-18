//
//  RequestModel.swift
//  URLSessionAPIServices
//
//  Created by Yusuf Demirci on 13.04.2020.
//  Copyright © 2020 Yusuf Demirci. All rights reserved.
//

import UIKit

enum RequestHTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

class RequestModel: NSObject {

    // MARK: - Properties
    var path: String
    var parameters: [String: Any?]
    var headers: [String: String]
    var method: RequestHTTPMethod
    var body: [String: Any?]

    init(path: String,
         method: RequestHTTPMethod,
         parameters: [String: Any?] = [:],
         headers: [String: String] = [:],
         body: [String: Any?] = [:]
    ) {
        self.path = path
        self.method = method
        self.parameters = parameters

        self.headers = [
            "Content-Language" : "ru-RU",
            "Content-Type" : "application/json;charset=UTF-8",
        ]
        for (k, v) in headers  {
            self.headers.updateValue(v, forKey: k)
        }
        self.body = body
        super.init()
    }
}

// MARK: - Public Functions
extension RequestModel {
    
    func urlRequest(baseURL: String) -> URLRequest {
        var endpoint: String = baseURL.appending(path)
        
        for parameter in parameters {
            if let value = parameter.value as? String {
                endpoint.append("?\(parameter.key)=\(value)")
            }
        }
        
        var request: URLRequest = URLRequest(url: URL(string: endpoint)!)
        
        request.httpMethod = method.rawValue
        
        for header in headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }
        
        if method == RequestHTTPMethod.post {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: JSONSerialization.WritingOptions.prettyPrinted)
            } catch let error {
                APILogManager.e("Request body parse error: \(error.localizedDescription)")
            }
        }
        
        return request
    }
}
