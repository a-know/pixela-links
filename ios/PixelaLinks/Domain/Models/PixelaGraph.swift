import Foundation

struct PixelaGraph: Identifiable, Decodable, Sendable {
    let id: String
    let name: String
    let unit: String
    let graphType: String

    enum CodingKeys: String, CodingKey {
        case id, name, unit
        case graphType = "type"
    }
}
