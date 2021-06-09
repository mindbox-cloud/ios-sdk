import Foundation

open class ProductListRequest: Encodable {
    public var product: ProductRequest?
    public var productGroup: ProductGroupRequest?
    public var count: Double?
    public var pricePerItem: Double?
    public var priceOfLine: Double?

    public init(
        product: ProductRequest? = nil,
        count: Double? = nil,
        pricePerItem: Double? = nil,
        priceOfLine: Double? = nil
    ) {
        self.product = product
        self.count = count
        self.pricePerItem = pricePerItem
        self.priceOfLine = priceOfLine
    }

    public init(
        productGroup: ProductGroupRequest? = nil,
        count: Double? = nil,
        pricePerItem: Double? = nil,
        priceOfLine: Double? = nil
    ) {
        self.productGroup = productGroup
        self.count = count
        self.pricePerItem = pricePerItem
        self.priceOfLine = priceOfLine
    }

    public init(
        productGroup: ProductGroupRequest? = nil,
        pricePerItem: Double? = nil
    ) {
        self.productGroup = productGroup
        self.pricePerItem = pricePerItem
    }

    public init(
        product: ProductRequest? = nil,
        pricePerItem: Double? = nil
    ) {
        self.product = product
        self.pricePerItem = pricePerItem
    }
}
