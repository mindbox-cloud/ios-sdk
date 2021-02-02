//
//  Loger.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

enum MBLoggerChanels: String {
    case system = "🤖"
    case network = "📡"
    case none
}

protocol ILogger: class {
    func log(inChanel: MBLoggerChanels, text: String)
}

class MBLogger: ILogger {
    func log(inChanel: MBLoggerChanels, text: String) {
	let config = LogerConfiguration()

        if config.enableChanels.contains(inChanel)  {
        	print(text)
        }
    }

    init() {
    }

}
