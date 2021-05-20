import Foundation

open class CouponRequest: Encodable {
    public var ids: IDS?
    public var pool: PoolRequest?

    public init(
        ids: IDS? = nil,
        pool: PoolRequest? = nil
    ) {
        self.ids = ids
        self.pool = pool
    }
}
