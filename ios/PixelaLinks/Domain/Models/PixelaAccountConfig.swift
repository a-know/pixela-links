import Foundation

struct PixelaAccountConfig: Equatable, Sendable {
    var username: String
    var isVerified: Bool

    var isConfigured: Bool { !username.isEmpty }

    init(username: String, isVerified: Bool = false) {
        self.username = username
        self.isVerified = isVerified
    }

    static let empty = PixelaAccountConfig(username: "")
}

// MARK: - UserDefaults persistence

extension PixelaAccountConfig {
    private static let usernameKey   = "pixela_username"
    private static let isVerifiedKey = "pixela_is_verified"

    static func load() -> PixelaAccountConfig {
        let username = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        // isVerifiedKey が未設定の場合（旧バージョンからの移行）は、
        // username と Keychain トークンが両方あれば接続済みとみなす
        let isVerified: Bool
        if UserDefaults.standard.object(forKey: isVerifiedKey) != nil {
            isVerified = UserDefaults.standard.bool(forKey: isVerifiedKey)
        } else {
            isVerified = !username.isEmpty && KeychainStore.loadToken() != nil
        }
        return PixelaAccountConfig(username: username, isVerified: isVerified)
    }

    func save() {
        UserDefaults.standard.set(username,   forKey: Self.usernameKey)
        UserDefaults.standard.set(isVerified, forKey: Self.isVerifiedKey)
    }
}
