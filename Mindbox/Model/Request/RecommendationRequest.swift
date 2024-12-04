import Foundation

open class RecommendationRequest: Encodable {
    public var limit: Int?
    public var area: AreaRequest?
    public var productCategory: ProductCategoryRequest?
    public var product: ProductRequest?

    public init(
        limit: Int,
        area: AreaRequest? = nil,
        productCategory: ProductCategoryRequest?
    ) {
        self.limit = limit
        self.area = area
        self.productCategory = productCategory
    }

    public init(
        limit: Int,
        area: AreaRequest? = nil,
        product: ProductRequest? = nil
    ) {
        self.limit = limit
        self.area = area
        self.product = product
    }
}
