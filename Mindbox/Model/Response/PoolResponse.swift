import Foundation

open class PoolResponse: Decodable {
    public let ids: IDS?
    public let name: String?
    public let poolDescription: String?
}
