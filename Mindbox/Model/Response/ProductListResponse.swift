import Foundation

open class ProductListResponse: Decodable {
    public let product: ProductResponse?
    public let productGroup: ProductGroupResponse?
    public let count: Decimal?
    public let priceOfLine: Decimal?
}
