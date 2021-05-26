//
//  Customer.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - Customer

public class Customer: Codable {
    public var authenticationTicket: String?
    public var discountCard: DiscountCard?
    public var birthDate, sex, timeZone, lastName: String?
    public var firstName, middleName, fullName: String?
    public var area: Area?
    public var email, mobilePhone: String?
    public var ids: IDS?
    public var customFields: CustomFields?
    public var subscriptions: [Subscription]

    public init(
        authenticationTicket: String?,
        discountCard: DiscountCard?,
        birthDate: String?,
        sex: String?,
        timeZone: String?,
        lastName: String?,
        firstName: String?,
        middleName: String?,
        fullName: String?,
        area: Area?,
        email: String?,
        mobilePhone: String?,
        ids: IDS?,
        customFields: CustomFields?,
        subscriptions: [Subscription]
    ) {
        self.authenticationTicket = authenticationTicket
        self.discountCard = discountCard
        self.birthDate = birthDate
        self.sex = sex
        self.timeZone = timeZone
        self.lastName = lastName
        self.firstName = firstName
        self.middleName = middleName
        self.fullName = fullName
        self.area = area
        self.email = email
        self.mobilePhone = mobilePhone
        self.ids = ids
        self.customFields = customFields
        self.subscriptions = subscriptions
    }

    // MARK: - Customerids

    public class IDS: Codable {
        public var websiteid, myAwesomeId: String?

        public init(websiteid: String, myAwesomeId: String) {
            self.websiteid = websiteid
            self.myAwesomeId = myAwesomeId
        }
    }
}
