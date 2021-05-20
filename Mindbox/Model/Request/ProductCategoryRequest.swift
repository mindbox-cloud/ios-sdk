import Foundation

open class ProductCategoryRequest: Encodable {
    public var ids: IDS?

    public init(ids: IDS? = nil) {
        self.ids = ids
    }
}
