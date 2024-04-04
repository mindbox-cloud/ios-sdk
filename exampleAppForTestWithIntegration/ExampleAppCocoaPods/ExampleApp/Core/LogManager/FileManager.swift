//
//  FileManager.swift
//  ExampleApp
//
//  Created by Sergei Semko on 4/2/24.
//

import Foundation

protocol FileManagerProtocol {
    func append(toFileNamed fileName: String, data: Data) throws
    func read(fileNamed fileName: String) throws -> Data
    func appendWithProtection(toFileNamed fileName: String, data: Data) throws
}

final class EAFileManager {
    
    let fileManager: FileManager
    
    private let fileAccessQueue = DispatchQueue(label: "com.app.fileAccessQueue")
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    private func makeURL(forFileNamed fileName: String) -> URL? {
        guard let url = fileManager.urls(
            for: .libraryDirectory,
            in: .userDomainMask).first
        else {
            return nil
        }

        return url.appending(path: fileName)
    }
    
    func appendSafely(fileNamed fileName: String, data: Data) throws {
        fileAccessQueue.async {
            do {
                try self.append(toFileNamed: fileName, data: data)
            } catch {
                debugPrint("Failed to append data safely: \(error.localizedDescription)")
            }
        }
    }
}

extension EAFileManager: FileManagerProtocol {
    func read(fileNamed fileName: String) throws -> Data {
        guard let url = makeURL(forFileNamed: fileName) else {
            throw FileManagerError.invalidDirectory
        }
        
        do {
            let data = try Data(contentsOf: url)
            return data
        } catch {
            throw FileManagerError.readingFailed
        }
    }
    
    func append(toFileNamed fileName: String, data: Data) throws {
        guard let url = makeURL(forFileNamed: fileName) else {
            throw FileManagerError.invalidDirectory
        }
        
        if !fileManager.fileExists(atPath: url.path) {
//            fileManager.createFile(atPath: url.path, contents: data)
            do {
                try data.write(to: url, options: [.noFileProtection, .atomic])
            } catch {
                throw FileManagerError.creatingFileFailed
            }
        } else {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: data)
                try fileHandle.close()
            } else {
                throw FileManagerError.writingFailed
            }
        }
    }
    
    func appendWithProtection(toFileNamed fileName: String, data: Data) throws {
        guard let url = makeURL(forFileNamed: fileName) else {
            throw FileManagerError.invalidDirectory
        }
        
        if !fileManager.fileExists(atPath: url.path) {
//            fileManager.createFile(atPath: url.path, contents: data)
            do {
                try data.write(to: url, options: [.completeFileProtection, .atomic])
            } catch {
                throw FileManagerError.creatingFileFailed
            }
        } else {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                do {
                    try fileHandle.seekToEnd()
                    try fileHandle.write(contentsOf: data)
                    try fileHandle.close()
                } catch {
                    throw FileManagerError.writingFailed
                }
            } else {
                throw FileManagerError.writingFailed
            }
        }
    }
}

enum FileManagerError: Error {
    case fileAlreadyExists
    case invalidDirectory
    case writingFailed
    case fileNotExist
    case readingFailed
    case creatingFileFailed
}
