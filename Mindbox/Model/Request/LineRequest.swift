import Foundation

open class LineRequest: Encodable {
    public var minPricePerItem: Decimal?
    public var costPricePerItem: Decimal?
    public var customFields: CustomFields?
    public var basePricePerItem: Decimal?
    public var quantityType: QuantityTypeRequest?
    public var discountedPricePerLine: Decimal?
    public var lineId: Int?
    public var lineNumber: Int?
    public var discounts: [DiscountRequest]?
    public var product: ProductRequest?

    public init(
        minPricePerItem: Decimal? = nil,
        costPricePerItem: Decimal? = nil,
        customFields: CustomFields? = nil,
        basePricePerItem: Decimal? = nil,
        quantity: QuantityTypeRequest? = nil,
        discountedPricePerLine: Decimal? = nil,
        lineId: Int? = nil,
        lineNumber: Int? = nil,
        discounts: [DiscountRequest]? = nil,
        product: ProductRequest? = nil
    ) {
        self.minPricePerItem = minPricePerItem
        self.costPricePerItem = costPricePerItem
        self.customFields = customFields
        self.basePricePerItem = basePricePerItem
        quantityType = quantity
        self.discountedPricePerLine = discountedPricePerLine
        self.lineId = lineId
        self.lineNumber = lineNumber
        self.discounts = discounts
        self.product = product
    }

    open func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(minPricePerItem, forKey: .minPricePerItem)
        try container.encodeIfPresent(costPricePerItem, forKey: .costPricePerItem)
        try container.encodeIfPresent(customFields, forKey: .customFields)
        try container.encodeIfPresent(basePricePerItem, forKey: .basePricePerItem)

        if let quantityType = quantityType {
            switch quantityType {
            case let .int(value):
                try container.encode(value, forKey: .quantity)
            case let .double(value):
                try container.encode(value, forKey: .quantity)
            }
        }

        try container.encodeIfPresent(quantityType?.description, forKey: .quantityType)

        try container.encodeIfPresent(discountedPricePerLine, forKey: .discountedPricePerLine)
        try container.encodeIfPresent(lineId, forKey: .lineId)
        try container.encodeIfPresent(lineNumber, forKey: .lineNumber)
        try container.encodeIfPresent(discounts, forKey: .discounts)
        try container.encodeIfPresent(product, forKey: .product)
    }

    enum CodingKeys: String, CodingKey {
        case minPricePerItem
        case costPricePerItem
        case customFields
        case basePricePerItem
        case quantity
        case quantityType
        case discountedPricePerLine
        case lineId
        case lineNumber
        case discounts
        case product
    }
}

public enum QuantityTypeRequest: CustomStringConvertible {
    case int(Int)
    case double(Decimal)

    public var description: String {
        switch self {
        case .double: return "double"
        case .int: return "int"
        }
    }
}
