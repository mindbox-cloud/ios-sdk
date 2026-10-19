//
//  EventRepository.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol EventRepository {
    func send(event: Event, completion: @escaping (Result<Void, MindboxError>) -> Void)
    func send<T>(type: T.Type, event: Event, completion: @escaping (Result<T, MindboxError>) -> Void) where T: Decodable

    /// Sends an event and returns the 2xx response body unparsed, so a body with a
    /// `ValidationError` status is still a success. `syncOperation` forwards this body
    /// to the page as is, and the page's tracker routes by its `status` field.
    func sendRaw(event: Event, completion: @escaping (Result<Data, MindboxError>) -> Void)

    func cancelAllRequests()
}
