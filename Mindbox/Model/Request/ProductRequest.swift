import Foundation

open class ProductRequest: Encodable {
    public var ids: IDS?

    public init(ids: IDS? = nil) {
        self.ids = ids
    }
}
