import Foundation

open class OrderRequest: Encodable {
    public var ids: IDS?
    public var cashdesk: CashdeskRequest?
    public var deliveryCost: Double?
    public var customFields: CustomFields?
    public var area: AreaRequest?
    public var totalPrice: Double?
    public var discounts: [DiscountRequest]?
    public var lines: [LineRequest]?
    public var email: String?
    public var mobilePhone: String?

    public init(
        ids: IDS? = nil,
        cashdesk: CashdeskRequest? = nil,
        deliveryCost: Double? = nil,
        customFields: CustomFields? = nil,
        area: AreaRequest? = nil,
        totalPrice: Double? = nil,
        discounts: [DiscountRequest]? = nil,
        lines: [LineRequest]? = nil,
        email: String? = nil,
        mobilePhone: String? = nil
    ) {
        self.ids = ids
        self.cashdesk = cashdesk
        self.deliveryCost = deliveryCost
        self.customFields = customFields
        self.area = area
        self.totalPrice = totalPrice
        self.discounts = discounts
        self.lines = lines
        self.email = email
        self.mobilePhone = mobilePhone
    }
}
