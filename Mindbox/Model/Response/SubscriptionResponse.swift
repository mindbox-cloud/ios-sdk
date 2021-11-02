import Foundation

open class SubscriptionResponse: Codable {
    public let pointOfContact: Channel?
    public let topic: String?
    public let isSubscribed: Bool?
}
