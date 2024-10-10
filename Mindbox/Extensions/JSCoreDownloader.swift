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
    private let session: URLSession
    public var savedFileURL: URL?

    private init() {
        let configuration = URLSessionConfiguration.default
        self.session = URLSession(configuration: configuration)
    }
    
    public func downloadFile(completion: (() -> Void)? = nil) {
        if let _ = savedFileURL {
            completion?()
            return
        }
        
        let fileURL = URL(string: "https://gist.githubusercontent.com/Vailence/16276f8d8f845528109b27ba7f270511/raw/gistfile1.txt")!
        let task = session.downloadTask(with: fileURL) { [weak self] tempLocalURL, response, error in
            
            guard let tempLocalURL = tempLocalURL else {
                completion?()
                return
            }

            self?.saveFile(fileURL: fileURL, tempLocalURL: tempLocalURL, completion: {
                completion?()
            })
        }
        
        task.resume()
    }
    
    private func saveFile(fileURL: URL, tempLocalURL: URL, completion: (() -> Void)? = nil) {
        let fileManager = FileManager.default

        do {
            let documentsDirectoryURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let savedURL = documentsDirectoryURL.appendingPathComponent(fileURL.lastPathComponent)
            
            if fileManager.fileExists(atPath: savedURL.path) {
                try fileManager.removeItem(at: savedURL)
            }
            
            try fileManager.moveItem(at: tempLocalURL, to: savedURL)
            self.savedFileURL = savedURL
            completion?()
        } catch {
            
        }
    }
    
    func getDict() -> [String: Any]? {
        guard let savedFileURL = savedFileURL else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: savedFileURL)
            
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                return json
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
    public func callMethod(key: String) -> String? {
        guard let dict = getDict(),
              let script = dict[key] as? String else {
            return nil
        }
        
        let jsContext = JSContext()
        
        jsContext?.exceptionHandler = { context, exception in
            if let exception = exception {
                print("JavaScript exception: \(exception)")
            }
        }
        
        jsContext?.evaluateScript(script)
        
        let function = jsContext?.objectForKeyedSubscript("calculate")
        let result = function?.call(withArguments: [])
        return result?.toString()
    }
    
    public func getSavedFileURL() -> URL? {
        return savedFileURL
    }
}
