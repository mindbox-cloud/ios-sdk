import Foundation

open class SubscriptionRequest: Codable {
    public var brand: String?
    public var pointOfContact: Channel?
    public var topic: String?
    public var isSubscribed: Bool

    public init(
        brand: String? = nil,
        pointOfContact: Channel? = nil,
        topic: String? = nil,
        isSubscribed: Bool
    ) {
        self.brand = brand
        self.pointOfContact = pointOfContact
        self.topic = topic
        self.isSubscribed = isSubscribed
    }
}
