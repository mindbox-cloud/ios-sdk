import Foundation

open class CustomerRequest: Encodable {
    public var authenticationTicket: String?
    public var discountCard: DiscountCardRequest?
    public var birthDate: DateOnly?
    public var sex: Sex?
    public var timeZone: String?
    public var lastName: String?
    public var firstName: String?
    public var middleName: String?
    public var fullName: String?
    public var area: AreaRequest?
    public var email: String?
    public var mobilePhone: String?
    public var ids: IDS?
    public var customFields: CustomFields?
    public var subscriptions: [SubscriptionRequest]?

    public init(
        authenticationTicket: String? = nil,
        discountCard: DiscountCardRequest? = nil,
        birthDate: DateOnly? = nil,
        sex: Sex? = nil,
        timeZone: TimeZone? = nil,
        lastName: String? = nil,
        firstName: String? = nil,
        middleName: String? = nil,
        fullName: String? = nil,
        area: AreaRequest? = nil,
        email: String? = nil,
        mobilePhone: String? = nil,
        ids: IDS? = nil,
        customFields: CustomFields? = nil,
        subscriptions: [SubscriptionRequest]? = nil
    ) {
        self.authenticationTicket = authenticationTicket
        self.discountCard = discountCard
        self.birthDate = birthDate
        self.sex = sex
        self.timeZone = timeZone?.identifier
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
}
