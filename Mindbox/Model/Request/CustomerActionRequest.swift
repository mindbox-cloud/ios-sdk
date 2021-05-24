import Foundation

open class CustomerActionRequest: Encodable {
    public var customFields: CustomFields?

    public init(customFields: CustomFields? = nil) {
        self.customFields = customFields
    }
}
