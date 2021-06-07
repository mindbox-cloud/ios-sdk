import Foundation

open class AreaRequest: Encodable {
    public var ids: IDS?

    public init(ids: IDS? = nil) {
        self.ids = ids
    }
}
