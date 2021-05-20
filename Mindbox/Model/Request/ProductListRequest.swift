import Foundation

open class ProductListRequest: Encodable {
    public var product: ProductRequest?
    public var productGroup: ProductGroupRequest?
    public var count: Decimal?
    public var pricePerItem: Decimal?
    public var priceOfLine: Decimal?

    public init(
        product: ProductRequest? = nil,
        productGroup: ProductGroupRequest? = nil,
        count: Decimal? = nil,
        pricePerItem: Decimal? = nil,
        priceOfLine: Decimal? = nil
    ) {
        self.product = product
        self.productGroup = productGroup
        self.count = count
        self.pricePerItem = pricePerItem
        self.priceOfLine = priceOfLine
    }
}

ProductListRequest(
    count: 0
)
