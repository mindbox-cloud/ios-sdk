import Foundation

open class ProductGroupRequest: Encodable {
    public var ids: IDS?

    public init(ids: IDS? = nil) {
        self.ids = ids
    }
}
