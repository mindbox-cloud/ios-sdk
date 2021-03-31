//
//  NetworkFetcher.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol NetworkFetcher {
    
    func requestObject<T: BaseResponse>(route: Route, completion: @escaping Completion<T>)
    func request(route: Route, completion: @escaping ((Result<Void, ErrorModel>) -> Void))

}
