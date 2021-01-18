//
//  File.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol IGuaranteedDeliveryQueue {
    var currentTask: GDRequest? {get}
    func addRequest(request: GDRequest)
}

protocol IGuaranteedDeliveryQueueDelegat {
    func queue(_ IGuaranteedDeliveryQueue: IGuaranteedDeliveryQueueDelegat, didSuccess: GDRequest)
    func queue(_ IGuaranteedDeliveryQueue: IGuaranteedDeliveryQueueDelegat, didFail: GDRequest)
}

protocol GDRequest: class {
    var executable: ((GDRequest)->Void) {get}
    var isValid: Bool {get}
    func execute()
    func onSuccess()
    func onFail()
    func cancel()
}

//class GuaranteedDeliveryQueue {
//    var currentTask: GDRequest? {
//        get {
//            return nil
//        }
//    }
//
//    init() {
//
//    }
//
//    var queue: [GDRequest] = []
//
//    func addRequest(request: GDRequest) {
//        queue.insert(request, at: 0)
//        tryNext()
//    }
//
//    func tryNext() {
//        guard currentTask == nil else {
//            return
//        }
//        guard let next = queue.last else {
//            print("GuaranteedDeliveryQueue queue is empty")
//        }
//
//        currentTask =
//    }
//}
