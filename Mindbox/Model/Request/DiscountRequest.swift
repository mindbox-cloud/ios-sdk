import Foundation

open class DiscountRequest: Encodable {
    public var type: DiscountTypeRequest?
    public var promoCode: DiscountPromoCodeRequest?
    public var externalPromoAction: DiscountExternalPromoActionRequest?
    public var amount: Decimal?

    public init(
        type: DiscountTypeRequest? = nil,
        promoCode: DiscountPromoCodeRequest? = nil,
        amount: Decimal? = nil
    ) {
        self.type = type
        self.promoCode = promoCode
        self.amount = amount
    }

    public init(
        type: DiscountTypeRequest? = nil,
        externalPromoAction: DiscountExternalPromoActionRequest? = nil,
        amount: Decimal? = nil
    ) {
        self.type = type
        self.amount = amount
        self.externalPromoAction = externalPromoAction
    }
}
