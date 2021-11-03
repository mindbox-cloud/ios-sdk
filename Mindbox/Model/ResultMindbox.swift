//
//  ResultMindbox.swift
//  Mindbox
//
//  Created by Plotnikov Mikhail on 03.11.2021.
//

import Foundation

public enum ResultMindbox {
    case success(String)
    case serverFailure(String)
    case clientFailure(MindboxError)
}
