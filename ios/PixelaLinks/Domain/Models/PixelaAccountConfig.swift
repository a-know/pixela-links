import Foundation

struct PixelaAccountConfig: Equatable, Sendable {
    var username: String

    var isConfigured: Bool { !username.isEmpty }

    static let empty = PixelaAccountConfig(username: "")
}

// MARK: - UserDefaults persistence

extension PixelaAccountConfig {
    private static let usernameKey = "pixela_username"

    static func load() -> PixelaAccountConfig {
        let username = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        return PixelaAccountConfig(username: username)
    }

    func save() {
        UserDefaults.standard.set(username, forKey: Self.usernameKey)
    }
}
