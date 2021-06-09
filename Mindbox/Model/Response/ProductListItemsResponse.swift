import Foundation

open class ProductListItemsResponse: Decodable {
    public let items: [ItemResponse]?
    public let processingStatus: ProcessingStatusResponse?
}
