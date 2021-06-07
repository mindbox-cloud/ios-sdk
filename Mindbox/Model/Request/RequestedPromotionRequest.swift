import Foundation

open class RequestedPromotionRequest: Encodable {
    public var type: PromotionType?
    public var promotion: AreaRequest?
    public var coupon: CouponRequest?
    public var amount: Decimal?

    public init(
        type: PromotionType?,
        promotion: AreaRequest?,
        coupon: CouponRequest? = nil,
        amount: Decimal?
    ) {
        self.type = type
        self.promotion = promotion
        self.coupon = coupon
        self.amount = amount
    }
}

public enum PromotionType: String, Codable {
    case balance
    case externalPromoAction
    case issuedCoupon
    case message
    case promoCode
    case discount
    case spentBonusPoints
    case earnedBonusPoints
}
