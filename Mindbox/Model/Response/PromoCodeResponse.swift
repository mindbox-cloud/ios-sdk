import Foundation
import MindboxLogger

open class PromoCodeResponse: Codable {
    public let issueStatus: IssueStatusResponse?
    public let ids: IDS?
    public let pool: PoolResponse?
    public let availableFromDateTimeUtc: DateTime?
    public let availableTillDateTimeUtc: DateTime?
    public let isUsed: Bool?
    public let usedPointOfContact: UsedPointOfContactResponse?
    public let usedDateTimeUtc: DateTime?
    public let issuedPointOfContact: IssuedPointOfContactResponse?
    public let issuedDateTimeUtc: DateTime?
    public let blockedDateTimeUtc: DateTime?
}

public enum IssueStatusResponse: String, UnknownCodable {
    case received = "Received"
    case promoCodeNotFound = "PromoCodeNotFound"
    case promoCodePoolNotFound = "PromoCodePoolNotFound"
    case noAvailablePromoCodesInPool = "NoAvailablePromoCodesInPool"
    case notInIssueDateTimeRange = "NotInIssueDateTimeRange"
    case notAvailableForIssue = "NotAvailableForIssue"
    case issued = "Issued"
    case unknown
}
