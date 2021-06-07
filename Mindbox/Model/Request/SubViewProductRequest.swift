import Foundation

open class SubViewProductRequest: Encodable {
    public var productGroup: ProductRequest?
    public var product: ProductRequest?
    public var customerAction: CustomerActionRequest?

    public init(
        productGroup: ProductRequest? = nil,
        product: ProductRequest? = nil,
        customerAction: CustomerActionRequest? = nil
    ) {
        self.productGroup = productGroup
        self.product = product
        self.customerAction = customerAction
    }
}
