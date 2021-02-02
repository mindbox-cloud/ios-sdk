//
//  MindBox.swift
//  MindBox
//
//  Created by Mikhail Barilov on 25.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

/// Enum which maps an appropiate symbol which added as prefix for each log message
///
/// - error: Log type error
/// - info: Log type info
/// - debug: Log type debug
/// - verbose: Log type verbose
/// - warning: Log type warning
/// - severe: Log type severe
enum LogType: String {
    case error = "[‼️]"
    case info = "[ℹ️]"
    case debug = "[💬]"
    case verbose = "[🔬]"
    case warning = "[⚠️]"
    case severe = "[🔥]"
}

internal extension Date {
    func toString() -> String {
        // FIX
        return Log.dateFormatter.string(from: self as Date)
    }
}

struct Log {
    @Injected static var logerServise: ILogger

    // MARK: - Properties
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm:ss.SSSS"
        return formatter
    }
    //    private static var isLoggingEnabled: Bool {
    //        #if DEBUG
    //        return true
    //        #else
    //        return false
    //        #endif
    //    }

    typealias Meta = (filename: String, line: Int, funcName: String)
    var text: String = ""
    var date: Date?
    var type: LogType?
    var chanel: MBLoggerChanels = .none
    var meta: Meta?
    var borders: (start: String, end: String) = ("[","\n]")

    init(_ object: Any?) {
        text = "\(String(describing: object))"
    }
    init(_ object: Any) {
        text = "\(String(describing: object))"
    }

    func make() {
        var header = ""
        if let type = type {
            header += type.rawValue + " "
        }
        if let date = date {
            header += date.toString() + " "
        }

        if let meta = meta {
            header += "[\(Log.sourceFileName(filePath: meta.filename))]:\(meta.line) \(meta.funcName)"
        }


        
        Log.logerServise.log(inChanel: .system, text: borders.start + header + "\n" + text + borders.end)
    }

    func inChanel(_ chanel: MBLoggerChanels) -> Log {
        var ret = self
        ret.chanel = chanel
        return ret
    }

    func withDate(_ date: Date = Date()) -> Log {
        var ret = self
        ret.date = date
        return ret
    }

    func withType(_ type: LogType) -> Log {
        var ret = self
        ret.type = type
        return ret
    }

    func withMeta(filename: String = #file, line: Int = #line, funcName: String = #function) -> Log {
        var ret = self
        ret.meta = (filename, line, funcName)
        return ret
    }

    func withBorders(start: String, end: String) -> Log {
        var ret = self
        ret.borders = (start, end)
        return ret
    }


    // MARK: - Public Functions
    init<T: Codable>(_ response: ResponseModel<T>, baseURL: String = "") {
        
        let path: String? = response.route?.path
        let dataJSON: String? = response.json
        
        var log: String = ""
        
        if let path = path {
            log = log + "[\(baseURL)\(path)]\n"
        }
        
        if let json = dataJSON {
            log = log + "\n[\(json)]"
        }

        self.text =  "LogManager: \n--- Response ---\n[\(Date().toString())] \n\(log) \n--- End ---\n"
        self.chanel = .network
    }
    
    init(error: ErrorModel) {
        //        guard isLoggingEnabled else { return }
        
        let errorKey: String? = error.errorKey
        let errorMessage: String? = error.errorMessage
        
        var log: String = ""

        if let status = error.httpStatusCode {
            log = log + "\n[httpStatusCode: \(status)]"
        }
        if let status = error.responseStatusCode {
            log = log + "\n[responseStatusCode: \(status)]"
        }
        if let errorKey = errorKey {
            log = log + "\n[key: \(errorKey)]"
        }
        if let errorMessage = errorMessage {
            log = log + "\n[message: \(errorMessage)]"
        }
        
        if log.isEmpty { return }
        
        self.text = "LogManager: \n--- Error ---\n[\(Date().toString())] \(log) \n--- End ---\n"
        self.chanel = .network
        self.type = .error
    }

    init(request: URLRequest) {

        let urlString = request.url?.absoluteString ?? ""
        let components = NSURLComponents(string: urlString)

        let method = request.httpMethod != nil ? "\(request.httpMethod!)": ""
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
        for (key,value) in request.allHTTPHeaderFields ?? [:] {
            requestLog += "\(key): \(value)\n"
        }
        requestLog += "\n"
        requestLog += "[Body]\n"
        if let body = request.httpBody{
            let bodyString = NSString(data: body, encoding: String.Encoding.utf8.rawValue) ?? "Can't render body; not utf8 encoded";
            requestLog += "\n\(bodyString)\n"
        }
        text = requestLog
        chanel = .network
        self.type = .debug
        self.borders = ("[---------- OUT ---------->\n", "------------------------>]")
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

        if let statusCode =  (response as? HTTPURLResponse)?.statusCode{
            responseLog += "HTTP \(statusCode) \(path)?\(query)\n"
        }
        if let host = components?.host{
            responseLog += "Host: \(host)\n"
        }
        for (key,value) in (response as? HTTPURLResponse)?.allHeaderFields ?? [:] {
            responseLog += "\(key): \(value)\n"
        }
        if let body = data{
            let bodyString = NSString(data: body, encoding: String.Encoding.utf8.rawValue) ?? "Can't render body; not utf8 encoded";
            responseLog += "\n\(bodyString)\n"
        }
        self.type = .debug
        if let error = error{
            responseLog += "\nError: \(error.localizedDescription)\n"
            self.type = .error
        }
        self.text = responseLog

        self.chanel = .network

        self.borders = ("[<---------- IN ----------\n", "<------------------------]")
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
