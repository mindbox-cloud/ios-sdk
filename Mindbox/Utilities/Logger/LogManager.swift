//
//  Mindbox.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 25.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

internal extension Date {
    func toString() -> String {
        return Log.dateFormatter.string(from: self as Date)
    }

    func toFullString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter.string(from: self as Date)
    }
}

struct Log {
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm:ss.SSSS"
        return formatter
    }

    typealias Meta = (filename: String, line: Int, funcName: String)

    var message: String = ""
    var date: Date?
    var level: LogLevel = .debug
    var category: LogCategory = .general
    var meta: Meta?
    var borders: (start: String, end: String) = ("[", "\n]")
    var subsystem: String = "cloud.Mindbox"

    init(_ object: Any?) {
        message = "\(String(describing: object))"
    }

    init(_ object: Any) {
        message = "\(String(describing: object))"
    }

    func make() {
        var header = subsystem + " "
        header += category.emoji + " "
        header += level.emoji + " "
        if let date = date {
            header += date.toString() + " "
        }

        if let meta = meta {
            header += "[\(Log.sourceFileName(filePath: meta.filename))]:\(meta.line) \(meta.funcName)"
        }
        Mindbox.logger.log(
            level: level,
            message: borders.start + header + "\n" + message + borders.end,
            category: category,
            subsystem: subsystem
        )
    }

    func subsystem(_ subsystem: String) -> Log {
        var ret = self
        ret.subsystem = subsystem
        return ret
    }

    func category(_ category: LogCategory) -> Log {
        var ret = self
        ret.category = category
        return ret
    }

    func withDate(_ date: Date = Date()) -> Log {
        var ret = self
        ret.date = date
        return ret
    }

    func level(_ type: LogLevel) -> Log {
        var ret = self
        ret.level = type
        return ret
    }

    func meta(filename: String = #file, line: Int = #line, funcName: String = #function) -> Log {
        var ret = self
        ret.meta = (filename, line, funcName)
        return ret
    }

    func borders(start: String, end: String) -> Log {
        var ret = self
        ret.borders = (start, end)
        return ret
    }

    // MARK: - Public Functions

    init(error: MindboxError) {
        var log: String = ""

        switch error {
        case .validationError:
            log = log + "\n[validationError: \(error.errorDescription ?? "No description")]"
        case let .protocolError(e):
            log = log + "\n[status: \(e.status)]"
            log = log + "\n[responseError: \(error.errorDescription ?? "No description")]"
            log = log + "\n[httpStatusCode: \(e.httpStatusCode)]"
        case let .serverError(e):
            log = log + "\n\(e.description)"
        case let .internalError(e):
            log = log + "\n[key: \(e.errorKey)]"
            if let rawError = e.rawError {
                log = log + "\n[message: \(rawError.localizedDescription)]"
            }
        case let .invalidResponse(e):
            guard let e = e else { return }
            log = log + "\n[response: \(String(describing: e))]"
        case .connectionError:
            log = log + "\n[connectionError]"
        case let .unknown(e):
            log = log + "\n[error: \(e.localizedDescription)]"
        }

        if log.isEmpty { return }

        message = "LogManager: \n--- Error ---\n[\(Date().toString())] \(log) \n--- End ---\n"
        category = .network
        level = .error
    }

    init(request: URLRequest, httpAdditionalHeaders: [AnyHashable: Any]? = nil) {
        let urlString = request.url?.absoluteString ?? ""
        let components = NSURLComponents(string: urlString)

        let method = request.httpMethod != nil ? "\(request.httpMethod!)" : ""
        let path = "\(components?.path ?? "")"
        let query = "\(components?.query ?? "")"
        let host = "\(components?.host ?? "")"

        var requestLog = ""
        requestLog += "[Url]\n"
        requestLog += "\(urlString)"
        requestLog += "\n\n"
        requestLog += "\(method) \(path)?\(query) HTTP/1.1\n"
        requestLog += "Host: \(host)\n"

        requestLog += "\n"
        requestLog += "[Headers]\n"
        httpAdditionalHeaders?.forEach {
            requestLog += "\($0.key): \($0.value)\n"
        }
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            requestLog += "\(key): \(value)\n"
        }
        requestLog += "\n"
        requestLog += "[Body]\n"
        if let body = request.httpBody {
            let bodyString = NSString(data: body, encoding: String.Encoding.utf8.rawValue) ?? "Can't render body; not utf8 encoded"
            requestLog += "\n\(bodyString)\n"
        }
        message = requestLog
        category = .network
        level = .debug
        borders = ("[---------- OUT ---------->\n", "------------------------>]")
    }

    init(data: Data?, response: URLResponse?, error: Error?) {
        let urlString = response?.url?.absoluteString
        let components = NSURLComponents(string: urlString ?? "")

        let path = "\(components?.path ?? "")"
        let query = "\(components?.query ?? "")"

        var responseLog = ""
        if let urlString = urlString {
            responseLog += "\(urlString)"
            responseLog += "\n\n"
        }

        if let statusCode = (response as? HTTPURLResponse)?.statusCode {
            responseLog += "HTTP \(statusCode) \(path)?\(query)\n"
        }
        if let host = components?.host {
            responseLog += "Host: \(host)\n"
        }
        for (key, value) in (response as? HTTPURLResponse)?.allHeaderFields ?? [:] {
            responseLog += "\(key): \(value)\n"
        }
        if let body = data,
           let object = try? JSONSerialization.jsonObject(with: body, options: []),
           let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
           let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
            responseLog += "\n\(prettyPrintedString)\n"
        }
        
        if let body = data {
            responseLog += "\n\(String(data: body, encoding: .utf8) ?? "")\n"
        }
        level = .debug
        if let error = error {
            responseLog += "\nError: \(error.localizedDescription)\n"
            level = .error
        }
        message = responseLog

        category = .network

        borders = ("[<---------- IN ----------\n", "<------------------------]")
    }
}

// MARK: - Private Functions

private extension Log {
    /// Extract the file name from the file path
    ///
    /// - Parameter filePath: Full file path in bundle
    /// - Returns: File Name with extension
    static func sourceFileName(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        return components.isEmpty ? "" : components.last!
    }
}
