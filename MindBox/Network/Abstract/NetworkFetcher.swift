//
//  NetworkFetcher.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol NetworkFetcher {
    
    typealias Completion<T: BaseResponse> = (Result<ResponseModel<T>, ErrorModel>) -> Void
    
    func request<T: BaseResponse>(route: Route, completion: @escaping Completion<T>)
    
}
