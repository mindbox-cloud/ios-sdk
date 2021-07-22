import Foundation

open class CustomerSegmentationResponse: Decodable {
    public let segmentation: SegmentResponse?
    public let segment: SegmentResponse?
}

open class SegmentResponse: Decodable {
    public let ids: IDS?
}
