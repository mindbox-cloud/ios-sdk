//
//  MobileApplicationRepository.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol MobileApplicationRepository {
    
    func installed(
        installationId: String?,
        apnsToken: String?,
        isNotificationsEnabled: Bool,
        completion: @escaping Completion<BaseResponse>
    )

    func infoUpdated(
        apnsToken: String?,
        isNotificationsEnabled: Bool,
        completion: @escaping Completion<BaseResponse>
    )
    
}
