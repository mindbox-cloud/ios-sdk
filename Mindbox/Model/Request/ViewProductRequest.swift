import Foundation

open class ViewProductRequest: Encodable {
    public var product: ProductRequest?
    public var productGroup: ProductGroupRequest?
    public var customerAction: CustomerActionRequest?

    public init(
        product: ProductRequest? = nil,
        productGroup: ProductGroupRequest? = nil,
        customerAction: CustomerActionRequest? = nil
    ) {
        self.product = product
        self.productGroup = productGroup
        self.customerAction = customerAction
    }

    public init(
        product: ProductRequest,
        customerAction: CustomerActionRequest?
    ) {
        self.product = product
        self.customerAction = customerAction
    }

    public init(
        productGroup: ProductGroupRequest,
        customerAction: CustomerActionRequest?
    ) {
        self.productGroup = productGroup
        self.customerAction = customerAction
    }

    public init(
        customerAction: CustomerActionRequest? = nil
    ) {
        self.customerAction = customerAction
    }
}
