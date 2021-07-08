import Foundation

open class DiscountCardResponse: Decodable {
    public let ids: IDS?
    public let customFields: CustomFields?
    public let status: StatusResponse?
    public let type: TypeResponse?
}
