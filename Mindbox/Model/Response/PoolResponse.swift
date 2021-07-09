import Foundation

open class PoolResponse: Decodable {
    public let ids: IDS?
    public let name: String?
    public let poolDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case ids
        case name
        case poolDescription = "description"
      }
}
