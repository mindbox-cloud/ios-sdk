//
//  JSCoreDownloader.swift
//  Mindbox
//
//  Created by vailence on 07.10.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import JavaScriptCore
import MindboxLogger

public class JSCoreDownloader {
    public static let shared = JSCoreDownloader()
    public var cachedJSON: [String: Any]? = nil
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        self.session = URLSession(configuration: configuration)
    }
    
    public func fetchJSON(completion: ((Result<Any, Error>) -> Void)? = nil) {
        if let cachedData = cachedJSON {
            completion?(.success(cachedData))
            return
        }
        
        let gistURL = URL(string: "https://gist.github.com/Vailence/16276f8d8f845528109b27ba7f270511/raw")!
        let task = session.dataTask(with: gistURL) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    let noDataError = NSError(domain: "JSCoreDownloader",
                                              code: -1,
                                              userInfo: [NSLocalizedDescriptionKey: "Нет данных для URL"])
                    completion?(.failure(noDataError))
                }
                return
            }
            
            guard let jsonString = String(data: data, encoding: .utf8),
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return
            }
            
            self?.cachedJSON = json
            completion?(.success(json))
        }
        
        task.resume()
    }
    
    public func callMethod(key: String) -> String? {
        let jsContext = JSContext()
        
        // Обрабатываем исключения JavaScript
        jsContext?.exceptionHandler = { context, exception in
            if let exception = exception {
                print("JavaScript exception: \(exception)")
            }
        }
        
        guard let cachedJSON = cachedJSON,
              let script = cachedJSON[key] as? String else {
            return nil
        }
        
        if let functionsDict = cachedJSON["functions"] as? [String: String] {
            for (functionName, functionBody) in functionsDict {
                let functionScript = "\(functionName) = \(functionBody);"
                jsContext?.evaluateScript(functionScript)
            }
        }
        
        jsContext?.evaluateScript(script)
        
        let function = jsContext?.objectForKeyedSubscript("calculate")
        let result = function?.call(withArguments: [])
        return result?.toString()
    }
}
