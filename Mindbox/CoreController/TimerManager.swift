//
//  TimerManager.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 28.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

public final class TimerManager {
    
    internal var didEnterBackgroundApplication: NSObjectProtocol?
    internal var didBecomeActiveApplication: NSObjectProtocol?
    
    internal var timer: Timer? {
        didSet {
            if didBecomeActiveApplication == nil && didEnterBackgroundApplication == nil {
                setupObservers()
            }
        }
    }
    internal var deadline: TimeInterval? = nil
    
    internal var seconds: TimeInterval = 0 {
        didSet {
            if seconds >= deadline ?? TimeInterval(Int.max) {
                block?()
                seconds = 0
            }
        }
    }
    
    internal var block: (() -> ())?
    
    internal func invalidate() {
        timer?.invalidate()
        timer = nil
        seconds = 0
        Logger.common(message: "The timer is stopped")
    }
    
    internal func removeObservers() {
        if didBecomeActiveApplication != nil && didEnterBackgroundApplication != nil {
            NotificationCenter.default.removeObserver(didEnterBackgroundApplication!)
            NotificationCenter.default.removeObserver(didBecomeActiveApplication!)
            didBecomeActiveApplication = nil
            didEnterBackgroundApplication = nil
        }
        
    }
    
    internal func setupObservers() {
        didEnterBackgroundApplication = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil) { [weak self] (_) in
            
            self?.invalidate()
        }
        
        
        didBecomeActiveApplication = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil) { [weak self] (_) in
        
            if self?.timer == nil {
                
                self?.setupTimer()
            }
        }
        
    }
    
    public func configurate(trackEvery seconds: TimeInterval?, block: (() -> ())?) {
        if seconds != nil {
            self.deadline = seconds
        }
        if block != nil {
            self.block = block
        }
        self.seconds = 0
        
    }
    
    public func setupTimer(trackEvery newDeadline: TimeInterval? = nil) {
        if newDeadline != nil {
            self.deadline = newDeadline!
        }
        self.seconds = 0
        
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.seconds += 1
        }
        
        guard let timer else { return }
        
        RunLoop.main.add(timer, forMode: .common)
        Logger.common(message: "The timer is running")
    }
}
