import Foundation
import Observation

@MainActor
@Observable
final class AccountSetupViewModel {
    var username: String = ""
    var token: String = ""
    var isValidating = false
    var isValidated = false
    var validationMessage: String?
    var validationIsSuccess = false

    var canValidate: Bool { !username.isEmpty && !token.isEmpty && !isValidating }
    var canSave: Bool { isValidated }

    func prefill(with account: PixelaAccountConfig) {
        username = account.username
        token = KeychainStore.loadToken() ?? ""
    }

    func validate() async {
        isValidating = true
        isValidated = false
        validationMessage = nil
        do {
            try await PixelaRepositoryImpl().validateAccount(username: username, token: token)
            isValidated = true
            validationIsSuccess = true
            validationMessage = "✓ 接続できました"
        } catch {
            validationIsSuccess = false
            validationMessage = "認証情報が正しくありません"
        }
        isValidating = false
    }

    func save() -> PixelaAccountConfig {
        let config = PixelaAccountConfig(username: username)
        config.save()
        try? KeychainStore.saveToken(token)
        return config
    }
}
