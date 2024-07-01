//
//  Cancelable.swift
//  Mindbox
//
//  Created by Sergei Semko on 7/1/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

public protocol Cancelable {
    func cancel()
}

public class MBCancelable {
    private var isCancelled = false
    private var task: URLSessionTask?
    
    func checkIfCanceled() -> Bool {
        return isCancelled
    }
    
    func setTask(_ task: URLSessionTask) {
        self.task = task
        if isCancelled {
            task.cancel()
        }
    }
}

extension MBCancelable: Cancelable {
    public func cancel() {
        isCancelled = true
        task?.cancel()
    }
}
