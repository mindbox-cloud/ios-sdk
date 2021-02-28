//
//  ParseEventOperation.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 28.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

final class ParseEventOperation: Operation {
    
    @Injected var databaseRepository: MBDatabaseRepository
    
    private let userInfo: [AnyHashable: Any]
    
    init(userInfo: [AnyHashable: Any]) {
        self.userInfo = userInfo
    }
    
    private var _isFinished: Bool = false
    override var isFinished: Bool {
        get {
            return _isFinished
        }
        set {
            willChangeValue(for: \.isFinished)
            _isFinished = newValue
            didChangeValue(for: \.isFinished)
        }
    }
    
    var onCompleted: ((_ result: Swift.Result<Event, Error>) -> Void)?

    override func main() {
        guard !isCancelled else {
            return
        }
        Log("Track request with userInfo: \(userInfo)")
            .inChanel(.notification).withType(.info).make()
        do {
            let payload = try parse(userInfo: userInfo)
            let event = makeEvent(with: payload)
            onCompleted?(.success(event))
            isFinished = true
        } catch let error {
            onCompleted?(.failure(error))
            isFinished = true
        }
    }
    
    private func parse(userInfo: [AnyHashable: Any]) throws -> Payload {
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
            let decoder = JSONDecoder()
            do {
                let payload = try decoder.decode(Payload.self, from: data)
                Log("Did parse payload: \(payload)")
                    .inChanel(.notification).withType(.info).make()
                return payload
            } catch {
                Log("Did fail to decode Payload with error: \(error.localizedDescription)")
                    .inChanel(.notification).withType(.error).make()
                throw error
            }
        } catch {
            Log("Did fail to serialize userInfo with error: \(error.localizedDescription)")
                .inChanel(.notification).withType(.error).make()
            throw error
        }
    }
    
    private func makeEvent(with payload: Payload) -> Event {
        let pushDelivered = PushDelivered(uniqKey: payload.uniqueKey)
        let event = Event(type: .pushDelivered, body: BodyEncoder(encodable: pushDelivered).body)
        return event
    }
    
}

fileprivate struct Payload: Codable, CustomDebugStringConvertible {
    
    let uniqueKey: String
    
    var debugDescription: String {
        "uniqueKey: \(uniqueKey)"
    }
    
}
