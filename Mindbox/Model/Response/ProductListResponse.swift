import Foundation

open class ProductListResponse: Decodable {
    public let product: ProductResponse?
    public let productGroup: ProductGroupResponse?
    public let count: Double?
    public let priceOfLine: Double?
}
