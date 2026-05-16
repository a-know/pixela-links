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
        let quantity = formatQuantity(delta)
        request.httpBody = try JSONEncoder().encode(PixelPayload(quantity: quantity))

        let (data, response) = try await NetworkClient.foregroundSession.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let rawMessage = (try? JSONDecoder().decode(PixelaResponse.self, from: data))?.message
            let message = rawMessage.map { $0 == "Quantity is invalid." ? "Quantity (\(quantity)) is invalid." : $0 }
            throw PixelaError.requestFailed(code, message)
        }
    }

    func updatePixel(value: Double, graphID: String) async throws {
        let account = PixelaAccountConfig.load()
        guard account.isConfigured, let token = KeychainStore.loadToken() else {
            throw PixelaError.authenticationFailed
        }
        let date = DateFormatter.pixelaDate.string(from: .now)
        let urlString = "https://pixe.la/v1/users/\(account.username)/graphs/\(graphID)/\(date)"
        guard let url = URL(string: urlString) else {
            throw PixelaError.requestFailed(0, nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(token, forHTTPHeaderField: "X-USER-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let quantity = formatQuantity(value)
        request.httpBody = try JSONEncoder().encode(PixelPayload(quantity: quantity))

        let (data, response) = try await NetworkClient.foregroundSession.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let rawMessage = (try? JSONDecoder().decode(PixelaResponse.self, from: data))?.message
            let message = rawMessage.map { $0 == "Quantity is invalid." ? "Quantity (\(quantity)) is invalid." : $0 }
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

    func createGraph(id: String, name: String, unit: String, type: String, color: String, timezone: String?, description: String?, isSecret: Bool) async throws {
        let account = PixelaAccountConfig.load()
        guard account.isConfigured, let token = KeychainStore.loadToken() else {
            throw PixelaError.authenticationFailed
        }
        guard let url = URL(string: "https://pixe.la/v1/users/\(account.username)/graphs") else {
            throw PixelaError.requestFailed(0, nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "X-USER-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CreateGraphPayload(id: id, name: name, unit: unit, type: type, color: color, timezone: timezone, description: description, isSecret: isSecret))

        let (data, response) = try await NetworkClient.foregroundSession.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = (try? JSONDecoder().decode(PixelaResponse.self, from: data))?.message
            throw PixelaError.requestFailed(code, message)
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        let rounded = value.rounded()
        // 0.1未満の差であれば整数とみなす（HealthKitが返す微小な小数誤差を吸収）
        if abs(value - rounded) < 0.1 {
            return String(Int(rounded))
        }
        return String(format: "%.2f", value)
    }
}

private struct PixelPayload: Encodable {
    let quantity: String
}

private struct CreateGraphPayload: Encodable {
    let id: String
    let name: String
    let unit: String
    let type: String
    let color: String
    let timezone: String?
    let description: String?
    let isSecret: Bool

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,       forKey: .id)
        try c.encode(name,     forKey: .name)
        try c.encode(unit,     forKey: .unit)
        try c.encode(type,     forKey: .type)
        try c.encode(color,    forKey: .color)
        try c.encodeIfPresent(timezone,    forKey: .timezone)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encode(isSecret, forKey: .isSecret)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, unit, type, color, timezone, description, isSecret
    }
}

private struct PixelaResponse: Decodable {
    let message: String?
}

private struct GraphListResponse: Decodable {
    let graphs: [PixelaGraph]
}
