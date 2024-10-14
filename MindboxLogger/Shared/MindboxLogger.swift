//
//  MindboxLogger.swift
//  MindboxLogger
//
//  Created by Akylbek Utekeshev on 01.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation
 
public class Logger {
    private typealias Meta = (filename: String, line: Int, funcName: String)
    private typealias Borders = (start: String, end: String)
    
    private static let subsystem: String = "cloud.Mindbox"
    private static func log(message: String,
                            level: LogLevel,
                            category: LogCategory,
                            meta: Meta,
                            borders: Borders,
                            subsystem: String? = nil) {
        var header = "\n"
        header += subsystem ?? self.subsystem + " "
        header += category.emoji + " "
        header += level.emoji + " "
        let timestamp = Date()
        header += timestamp.toString() + " "

        header += "\n[\(sourceFileName(filePath: meta.filename))]:\(meta.line) \(meta.funcName)"
        
        MBLogger.shared.log(
            level: level,
            message: borders.start + message + borders.end,
            date: timestamp,
            category: category,
            subsystem: subsystem ?? "cloud.Mindbox"
        )
    }
    
    public static func error(_ error: LoggerErrorModel,
                             level: LogLevel = .error,
                             category: LogCategory = .network,
                             fileName: String = #file,
                             line: Int = #line,
                             funcName: String = #function) {
        var logMessage: String = ""
        logMessage = logMessage + "\n[\(error.errorType.rawValue) error: \(error.description ?? "No description")]"
        if let status = error.status {
            logMessage = logMessage + "\n[status: \(status)]"
        }
        
        if let statusCode = error.statusCode {
            logMessage = logMessage + "\n[httpStatusCode: \(statusCode)]"
        }
        
        if logMessage.isEmpty { return }

        let message = "LogManager: \n--- Error --- \(String(describing: logMessage)) \n--- End ---\n"
        
        let meta: Meta = (fileName, line, funcName)
        let borders: Borders = ("", "\n")
        log(message: message, level: .debug, category: .network, meta: meta, borders: borders)
    }
    
    @available(*, deprecated, message: "Method deprecated. Use error(_ error: LoggerErrorModel:) instead")
    public static func error(_ error: MindboxError,
                             level: LogLevel = .error,
                             category: LogCategory = .network,
                             fileName: String = #file,
                             line: Int = #line,
                             funcName: String = #function
    ) {
        var logMessage: String = ""

        switch error {
        case .validationError:
            logMessage = logMessage + "\n[validationError: \(error.errorDescription ?? "No description")]"
        case let .protocolError(e):
            logMessage = logMessage + "\n[status: \(e.status)]"
            logMessage = logMessage + "\n[responseError: \(error.errorDescription ?? "No description")]"
            logMessage = logMessage + "\n[httpStatusCode: \(e.httpStatusCode)]"
        case let .serverError(e):
            logMessage = logMessage + "\n\(e.description)"
        case let .internalError(e):
            logMessage = logMessage + "\n[key: \(e.errorKey)]"
            if let rawError = e.rawError {
                logMessage = logMessage + "\n[message: \(rawError.localizedDescription)]"
            }
        case let .invalidResponse(e):
            guard let e = e else { return }
            logMessage = logMessage + "\n[response: \(String(describing: e))]"
        case .connectionError:
            logMessage = logMessage + "\n[connectionError]"
        case let .unknown(e):
            logMessage = logMessage + "\n[error: \(e.localizedDescription)]"
        }

        if logMessage.isEmpty { return }

        let message = "LogManager: \n--- Error --- \(String(describing: logMessage)) \n--- End ---\n"
        
        let meta: Meta = (fileName, line, funcName)
        let borders: Borders = ("", "\n")
        log(message: message, level: .debug, category: .network, meta: meta, borders: borders)
    }
    
    public static func network(request: URLRequest,
                               httpAdditionalHeaders: [AnyHashable: Any]? = nil,
                               fileName: String = #file,
                               line: Int = #line,
                               funcName: String = #function) {
        
        let urlString = request.url?.absoluteString ?? ""
        let components = NSURLComponents(string: urlString)

        let method = "\(request.httpMethod ?? "")"
        let path = "\(components?.path ?? "")"
        let query = "\(components?.query ?? "")"
        let host = "\(components?.host ?? "")"

        var requestLog = ""
        requestLog += "[Url]: \(urlString)"
        requestLog += "[Method]: \(method) \(path)?\(query) HTTP/1.1\n"
        requestLog += "[Host]: \(host)\n"

        requestLog += "\n"
        requestLog += "[Headers]: \n"
        httpAdditionalHeaders?.forEach {
            requestLog += "\($0.key): \($0.value)\n"
        }
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            requestLog += "\(key): \(value)\n"
        }

        if let body = request.httpBody {
            requestLog += "\n[Body]: \n"
            let bodyString = NSString(data: body, encoding: String.Encoding.utf8.rawValue) ?? "Can't render body; not utf8 encoded"
            requestLog += "\n\(bodyString)\n"
        }
        
        let message = requestLog
        let meta: Meta = (fileName, line, funcName)
        let borders: Borders = ("\n[---------- OUT ---------->\n", "\n------------------------>]")
        log(message: message, level: .debug, category: .network, meta: meta, borders: borders)
    }
    
    public static func response(data: Data?,
                                response: URLResponse?,
                                error: Error?,
                                fileName: String = #file,
                                line: Int = #line,
                                funcName: String = #function) {
        let urlString = response?.url?.absoluteString
        let components = NSURLComponents(string: urlString ?? "")

        let path = "\(components?.path ?? "")"
        let query = "\(components?.query ?? "")"

        var responseLog = ""
        if let urlString = urlString {
            responseLog += "[Url]: \(urlString)\n"
        }

        if let statusCode = (response as? HTTPURLResponse)?.statusCode {
            responseLog += "[Status code]: HTTP \(statusCode) \(path)?\(query)\n"
        }
        if let host = components?.host {
            responseLog += "[Host]: \(host)\n"
        }

//        for (key, value) in (response as? HTTPURLResponse)?.allHeaderFields ?? [:] {
//            responseLog += "\(key): \(value)\n"
//        }
        
        if let body = data,
           let object = try? JSONSerialization.jsonObject(with: body, options: []),
           let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
           let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
            responseLog += "[Body]: \n\(prettyPrintedString)\n"
        }
//
//        if let body = data {
//            responseLog += "[Body]: \n\(String(data: body, encoding: .utf8) ?? "")\n"
//        }
        
        var level: LogLevel = .debug
        if let error = error {
            responseLog += "\n[Error]: \(error.localizedDescription)\n"
            level = .error
        }
        let message = responseLog
        let meta: Meta = (fileName, line, funcName)
        let borders: Borders = ("\n[<---------- IN ----------\n", "\n<------------------------]")
        log(message: message, level: level, category: .network, meta: meta, borders: borders)
    }
    
    public static func common(message: String,
                              level: LogLevel = .debug,
                              category: LogCategory = .general,
                              subsystem: String? = nil,
                              fileName: String = #file,
                              line: Int = #line,
                              funcName: String = #function) {
        let meta: Meta = (fileName, line, funcName)
        let borders: Borders = ("", "\n")
        log(message: message, level: level, category: category, meta: meta, borders: borders, subsystem: subsystem)
    }
}

// MARK: - Private Functions
private extension Logger {
    /// Extract the file name from the file path
    ///
    /// - Parameter filePath: Full file path in bundle
    /// - Returns: File Name with extension
    static func sourceFileName(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        return components.last ?? ""
    }
}
