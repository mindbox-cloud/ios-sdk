import Foundation

open class ProductListResponse: Codable {
    public let product: ProductResponse?
    public let productGroup: ProductGroupResponse?
    public let count: Double?
    public let priceOfLine: Double?
    public let price: Double?
}
