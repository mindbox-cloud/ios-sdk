import Foundation

open class DiscountRequest: Encodable {
    public var type: DiscountTypeRequest?
    public var promoCode: DiscountPromoCodeRequest?
    public var amount: Decimal?
    public var externalPromoAction: AreaRequest?

    public init(
        type: DiscountTypeRequest? = nil,
        promoCode: DiscountPromoCodeRequest? = nil,
        amount: Decimal? = nil,
        externalPromoAction: AreaRequest? = nil
    ) {
        self.type = type
        self.promoCode = promoCode
        self.amount = amount
        self.externalPromoAction = externalPromoAction
    }
}
