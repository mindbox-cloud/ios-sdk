//
//  Typealiases.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

typealias HTTPHeaders = [String: String]

typealias QueryParameters = [String: CustomStringConvertible]

typealias Completion<T: BaseResponse> = (Result<ResponseModel<T>, ErrorModel>) -> Void
