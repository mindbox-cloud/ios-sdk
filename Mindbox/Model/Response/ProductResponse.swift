import Foundation

open class ProductResponse: Codable {
    public let ids: IDS?
    public let name: String?
    public let displayName: String?
    public let url: String?
    public let pictureUrl: String?
    public let price: Double?
    public let oldPrice: Double?
    public let customFields: CustomFields?
}
