import Foundation

open class SubscriptionResponse: Decodable {
    public let pointOfContact: Channel?
    public let topic: String?
    public let isSubscribed: Bool?
}
