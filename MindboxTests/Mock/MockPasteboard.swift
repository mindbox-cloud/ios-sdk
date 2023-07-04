//
//  MockPasteboard.swift
//  MindboxTests
//
//  Created by vailence on 04.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit

public class MockPasteboard: UIPasteboard {
    public var copiedString: String?

    override public var string: String? {
        get { copiedString }
        set { copiedString = newValue }
    }
}
