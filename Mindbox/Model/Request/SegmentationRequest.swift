import Foundation

open class SegmentationRequest: Encodable {
    public var ids: IDS?

    public init(ids: IDS? = nil) {
        self.ids = ids
    }
}
