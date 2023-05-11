//
//  InAppMessage.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

/// Domain model that contains all data needed to show inapp on screen
struct InAppFormData {
    let inAppId: String
    let image: UIImage
    let redirectUrl: String
    let intentPayload: String
}

struct InAppTransitionData {
    let inAppId: String
    let imageUrl: String
    let redirectUrl: String
    let intentPayload: String
}