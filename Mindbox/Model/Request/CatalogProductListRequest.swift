import Foundation

open class CatalogProductListRequest: Encodable {
    public var calculationDateTimeUtc: DateTime?
    public var area: AreaRequest?
    public var items: [ItemRequest]?

    public init(
        calculationDateTimeUtc: DateTime? = nil,
        area: AreaRequest? = nil,
        items: [ItemRequest]? = nil
    ) {
        self.calculationDateTimeUtc = calculationDateTimeUtc
        self.area = area
        self.items = items
    }
}
