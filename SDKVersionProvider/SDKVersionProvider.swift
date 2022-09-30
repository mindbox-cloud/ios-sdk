//
//  SDKVersionProvider.swift
//  
//
//  Created by Максим Казаков on 30.09.2022.
//

import Foundation

// Fetches SDK version only when SDK is destributed via SPM
#if SWIFT_PACKAGE
public let sdkVersion: String = {
    let bundle = Bundle.module
    do {
        guard let url = bundle.url(forResource: "SDKVersionConfig", withExtension: "xcconfig") else {
            throw NSError(domain: "sdkVersion", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to find SDKVersionConfig.xcconfig"])
        }
        let projectConfigString = try String(contentsOf: url)
        let range = NSRange(
            projectConfigString.startIndex..<projectConfigString.endIndex,
            in: projectConfigString
        )
        let capturePattern = #"MARKETING_VERSION = ([\d\.]+)"#
        let captureRegex = try NSRegularExpression(pattern: capturePattern)
        let matches = captureRegex.matches(in: projectConfigString, options: [], range: range)
        guard let match = matches.first, match.numberOfRanges > 1 else {
            throw NSError(domain: "sdkVersion", code: -1, userInfo: [NSLocalizedDescriptionKey: "MARKETING_VERSION not found in SDKVersionConfig.xcconfig"])
        }
        let matchRange = match.range(at: 1)
        guard let substringRange = Range(matchRange, in: projectConfigString) else {
            throw NSError(domain: "sdkVersion", code: -1, userInfo: [NSLocalizedDescriptionKey: "MARKETING_VERSION not found in SDKVersionConfig.xcconfig"])
        }
        let capture = String(projectConfigString[substringRange])
        return capture
    } catch {
        fatalError("SDK version cannot be determined. Error: \(error.localizedDescription)")
    }
}()
#endif
