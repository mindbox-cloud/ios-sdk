import Foundation

open class DiscountPromoCodeRequest: Codable {
    public var ids: IDS?

    public init(ids: IDS? = nil) {
        self.ids = ids
    }
}
