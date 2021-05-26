import Foundation

open class RequestedPromotionRequest: Encodable {
    public var type: String
    public var promotion: AreaRequest?
    public var coupon: CouponRequest?
    public var amount: Decimal?

    public init(
        type: String,
        promotion: AreaRequest,
        coupon: CouponRequest? = nil,
        amount: Decimal
    ) {
        self.type = type
        self.promotion = promotion
        self.coupon = coupon
        self.amount = amount
    }
}
