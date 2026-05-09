import Foundation

protocol PixelaRepository: Sendable {
    func addPixel(delta: Double, graphID: String) async throws
    func validateAccount(username: String, token: String) async throws
    func fetchGraphs() async throws -> [PixelaGraph]
}

enum PixelaError: Error {
    case requestFailed(Int)
    case authenticationFailed
    case networkError(Error)

    var statusCode: Int? {
        if case .requestFailed(let code) = self { return code }
        return nil
    }
}
