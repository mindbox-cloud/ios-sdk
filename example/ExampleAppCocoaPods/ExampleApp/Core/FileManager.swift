//
//  FileManager.swift
//  ExampleApp
//
//  Created by Sergei Semko on 4/2/24.
//

import Foundation

protocol FileManagerProtocol {
    func append(toFileNamed fileName: String, data: Data) throws
}

final class EAFileManager {
    
    let fileManager: FileManager
    
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
}

extension EAFileManager: FileManagerProtocol {
    func append(toFileNamed fileName: String, data: Data) throws {
        guard let url = makeURL(forFileNamed: fileName) else {
            throw FileManagerError.invalidDirectory
        }
        
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: data)
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
}

enum FileManagerError: Error {
    case fileAlreadyExists
    case invalidDirectory
    case writingFailed
    case fileNotExist
    case readingFailed
}
