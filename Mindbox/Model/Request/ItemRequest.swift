import Foundation

open class ItemRequest: Encodable {
    public var product: ProductRequest?
    public var basePricePerItem: Decimal?
    public var minPricePerItem: Decimal?
    public var requestedPromotions: [RequestedPromotionRequest]?

    public init(
        product: ProductRequest? = nil,
        basePricePerItem: Decimal? = nil,
        minPricePerItem: Decimal? = nil,
        requestedPromotions: [RequestedPromotionRequest]? = nil
    ) {
        self.product = product
        self.basePricePerItem = basePricePerItem
        self.minPricePerItem = minPricePerItem
        self.requestedPromotions = requestedPromotions
    }
}
