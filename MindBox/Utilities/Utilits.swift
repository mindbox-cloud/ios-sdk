//
//  Utilities.swift
//  MindBox
//
//  Created by Mikhail Barilov on 20.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol IFetchUtilities {

//    var oldAdvertising: String? { get }

    func getIDFA(
        onSuccess: @escaping ((UUID) -> Void),
        onFail: @escaping (() -> Void)
    )
    func getIDFV(
        tryCount: Int,
        onSuccess: @escaping ((UUID)->Void),
        onFail: @escaping (()->Void)
    )
}

class Utilities {
    @Injected static var fetch: IFetchUtilities

}
