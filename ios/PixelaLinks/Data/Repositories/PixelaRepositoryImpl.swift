import Foundation

struct PixelaRepositoryImpl: PixelaRepository {
    func addPixel(delta: Double, graphID: String) async throws {
        let account = PixelaAccountConfig.load()
        guard account.isConfigured, let token = KeychainStore.loadToken() else {
            throw PixelaError.authenticationFailed
        }
        let urlString = "https://pixe.la/v1/users/\(account.username)/graphs/\(graphID)/add"
        guard let url = URL(string: urlString) else {
            throw PixelaError.requestFailed(0, nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(token, forHTTPHeaderField: "X-USER-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(PixelPayload(quantity: formatQuantity(delta)))

        let (data, response) = try await NetworkClient.foregroundSession.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = (try? JSONDecoder().decode(PixelaResponse.self, from: data))?.message
            throw PixelaError.requestFailed(code, message)
        }
    }

    func validateAccount(username: String, token: String) async throws {
        guard let url = URL(string: "https://pixe.la/v1/users/\(username)/authentication") else {
            throw PixelaError.requestFailed(0, nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "X-USER-TOKEN")

        let (_, response) = try await NetworkClient.foregroundSession.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw PixelaError.authenticationFailed
        }
    }

    func fetchGraphs() async throws -> [PixelaGraph] {
        let account = PixelaAccountConfig.load()
        guard account.isConfigured, let token = KeychainStore.loadToken() else {
            throw PixelaError.authenticationFailed
        }
        guard let url = URL(string: "https://pixe.la/v1/users/\(account.username)/graphs") else {
            throw PixelaError.requestFailed(0, nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "X-USER-TOKEN")

        let (data, response) = try await NetworkClient.foregroundSession.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = (try? JSONDecoder().decode(PixelaResponse.self, from: data))?.message
            throw PixelaError.requestFailed(code, message)
        }
        return try JSONDecoder().decode(GraphListResponse.self, from: data).graphs
    }

    private func formatQuantity(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.2f", value)
    }
}

private struct PixelPayload: Encodable {
    let quantity: String
}

private struct PixelaResponse: Decodable {
    let message: String?
}

private struct GraphListResponse: Decodable {
    let graphs: [PixelaGraph]
}
