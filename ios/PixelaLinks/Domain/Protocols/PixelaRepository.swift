import Foundation

protocol PixelaRepository: Sendable {
    func addPixel(delta: Double, graphID: String) async throws
    func updatePixel(value: Double, graphID: String) async throws
    func validateAccount(username: String, token: String) async throws
    func fetchGraphs() async throws -> [PixelaGraph]
    func createGraph(id: String, name: String, unit: String, type: String, color: String, timezone: String?, description: String?, isSecret: Bool) async throws
    func batchPostPixels(pixels: [(date: String, quantity: String)], graphID: String) async throws
}

enum PixelaError: Error, LocalizedError {
    case requestFailed(Int, String?)   // status code, server message
    case authenticationFailed
    case networkError(Error)

    var statusCode: Int? {
        if case .requestFailed(let code, _) = self { return code }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .requestFailed(_, let message): return message ?? "Pixela APIエラー"
        case .authenticationFailed:          return "認証エラー"
        case .networkError(let e):           return e.localizedDescription
        }
    }
}
