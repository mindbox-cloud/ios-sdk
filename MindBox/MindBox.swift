//
//  MindBox.swift
//  MindBox
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class MindBox {
    public static var shared: MindBox = {
		return MindBox()
    }()
    // MARK: - Elemets

    // MARK: - Property

    // MARK: - Init

    private init() {
    }

    // MARK: - MindBox

    public func initialization() {
		print("Log MindBox start initialization")
    }

    // MARK: - Private
}
