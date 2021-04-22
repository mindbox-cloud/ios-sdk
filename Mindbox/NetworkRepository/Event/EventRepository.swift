//
//  EventRepository.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol EventRepository {
    
    func send(event: Event, completion: @escaping (Result<Void, ErrorModel>) -> Void)
    
}
