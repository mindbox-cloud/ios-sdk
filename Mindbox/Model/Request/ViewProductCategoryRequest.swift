import Foundation

open class ViewProductCategoryRequest: Encodable {
    public var productCategory: ProductCategoryRequest?
    public var customerAction: CustomerActionRequest?

    public init(
        productCategory: ProductCategoryRequest? = nil,
        customerAction: CustomerActionRequest? = nil
    ) {
        self.productCategory = productCategory
        self.customerAction = customerAction
    }
}
