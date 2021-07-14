import Foundation

open class ItemRequest: Encodable {
    public var product: ProductRequest?
    public var basePricePerItem: Double?
    public var minPricePerItem: Double?
    public var requestedPromotions: [RequestedPromotionRequest]?

    public init(
        product: ProductRequest? = nil,
        basePricePerItem: Double? = nil,
        minPricePerItem: Double? = nil,
        requestedPromotions: [RequestedPromotionRequest]? = nil
    ) {
        self.product = product
        self.basePricePerItem = basePricePerItem
        self.minPricePerItem = minPricePerItem
        self.requestedPromotions = requestedPromotions
    }
}
