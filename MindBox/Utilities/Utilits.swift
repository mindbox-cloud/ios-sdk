//
//  Utilities.swift
//  MindBox
//
//  Created by Mikhail Barilov on 20.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit.UIApplication

protocol IFetchUtilities {

    var appVerson: String? {get}
    var sdkVersion: String? {get}
    var hostApplicationName: String? {get}

    func getIDFA(
        onSuccess: @escaping ((UUID) -> Void),
        onFail: @escaping (() -> Void)
    )
    func getIDFV(
        tryCount: Int,
        onSuccess: @escaping ((UUID)->Void),
        onFail: @escaping (()->Void)
    )
}

class Utilities {
    @Injected static var fetch: IFetchUtilities

    class func isValidURL(string: String) -> Bool {
        let urlPattern = "^(http|https|ftp)\\://([a-zA-Z0-9\\.\\-]+(\\:[a-zA-Z0-9\\.&amp;%\\$\\-]+)*@)*((25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9])\\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9]|0)\\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9]|0)\\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[0-9])|localhost|([a-zA-Z0-9\\-]+\\.)*[a-zA-Z0-9\\-]+\\.(com|edu|gov|int|mil|net|org|biz|arpa|info|name|pro|aero|coop|museum|[a-zA-Z]{2}))(\\:[0-9]+)*(/($|[a-zA-Z0-9\\.\\,\\?\\'\\\\\\+&amp;%\\$#\\=~_\\-]+))*$"
        return self.matches(string: string, pattern: urlPattern)
    }

    class func matches(string: String ,pattern: String) -> Bool {
        let regex = try! NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive])
        return regex.firstMatch(
            in: string,
            options: [],
            range: NSRange(location: 0, length: string.utf16.count)) != nil
    }

    static func checkUUID(string: String) -> Bool {
    var str = string
        str = str.replacingOccurrences(of: "0", with: "")
        str = str.replacingOccurrences(of: "-", with: "")

        return !str.isEmpty
    }
}
