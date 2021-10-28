import Foundation

open class CustomerSegmentationResponse: Codable {
    public let segmentation: SegmentResponse?
    public let segment: SegmentResponse?
}

open class SegmentResponse: Codable {
    public let ids: IDS?
}
