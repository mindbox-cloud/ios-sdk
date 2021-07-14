import Foundation

open class CustomerResponse: Decodable {
    public let ids: IDS?
    public let area: AreaResponse?
    public let subscriptions: [SubscriptionResponse]?
    public let discountCard: DiscountCardResponse?
    public let birthDate: DateOnly?
    public let sex: Sex?
    public let timeZone: String?
    public let lastName: String?
    public let firstName: String?
    public let middleName: String?
    public let fullName: String?
    public let email: String?
    public let mobilePhone: Int?
    public let customFields: CustomFields?
    public let processingStatus: String?
    public let isEmailInvalid: Bool?
    public let isMobilePhoneInvalid: Bool?
    public let changeDateTimeUtc: DateTime?
    public let ianaTimeZone: String?
    public let timeZoneSource: String?
}
