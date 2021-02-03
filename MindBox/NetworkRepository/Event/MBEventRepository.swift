//
//  MBEventRepository.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MBEventRepository: EventRepository {
    
    private let fetcher: NetworkFetcher
    
    private let configuration: MBConfiguration
    
    init(fetcher: NetworkFetcher, configuration: MBConfiguration) {
        self.fetcher = fetcher
        self.configuration = configuration
    }
    
    func send(event: Event, completion: @escaping Completion<BaseResponse>) {
        let route = EventRoute.asyncEvent(event: event, configuration: configuration)
        fetcher.request(route: route, completion: completion)
    }
    
}
