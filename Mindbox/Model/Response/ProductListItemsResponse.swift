import Foundation

open class ProductListItemsResponse: Codable {
    public let items: [ItemResponse]?
    public let processingStatus: ProcessingStatusResponse?
}
