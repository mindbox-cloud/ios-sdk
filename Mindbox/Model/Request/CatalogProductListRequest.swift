import Foundation

open class CatalogProductListRequest: Encodable {
    public var area: AreaRequest?
    public var items: [ItemRequest]?

    public init(
        area: AreaRequest? = nil,
        items: [ItemRequest]? = nil
    ) {
        self.area = area
        self.items = items
    }
}
