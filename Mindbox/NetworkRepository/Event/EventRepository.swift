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

    /// Sends an event and returns the raw HTTP 2xx response body. Skips
    /// `BaseResponse` parsing so the caller can dispatch on the body itself
    /// (e.g. forward the bytes verbatim to the WebView JS bridge so the JS
    /// Tracker can route by the body's `status` field).
    func sendRaw(event: Event, completion: @escaping (Result<Data, MindboxError>) -> Void)

    /// Cancels all ongoing network requests associated with this repository.
    func cancelAllRequests()
}
