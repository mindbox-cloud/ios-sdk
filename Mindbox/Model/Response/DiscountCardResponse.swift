import Foundation

open class DiscountCardResponse: Codable {
    public let ids: IDS?
    public let customFields: CustomFields?
    public let status: StatusResponse?
    public let type: BalanceTypeReponse?
}
