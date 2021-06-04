import Foundation

open class RecommendationResponse: Decodable {
    public let name: String?
    public let description: String?
    public let displayName: String?
    public let url: URL?
    public let pictureUrl: URL?
    public let price: Decimal?
    public let oldPrice: Decimal?
    public let category: String?
    public let vendorCode: String?
    public let ids: IDS?
    public let manufacturer: ManufacturerResponse?
    public let customFields: CustomFields?
}
