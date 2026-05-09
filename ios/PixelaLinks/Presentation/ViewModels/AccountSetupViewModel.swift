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
    var savedConfig: PixelaAccountConfig? = nil

    func prefill(with account: PixelaAccountConfig) {
        username = account.username
        token = KeychainStore.loadToken() ?? ""
        if account.isVerified {
            isValidated = true
            validationIsSuccess = true
            validationMessage = "✓ 接続済み"
        }
    }

    func resetValidation() {
        isValidated = false
        validationIsSuccess = false
        validationMessage = nil
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
            savedConfig = save()
        } catch {
            validationIsSuccess = false
            validationMessage = "認証情報が正しくありません"
        }
        isValidating = false
    }

    func save() -> PixelaAccountConfig {
        let config = PixelaAccountConfig(username: username, isVerified: isValidated)
        config.save()
        try? KeychainStore.saveToken(token)
        return config
    }

    func disconnect() {
        isValidated = false
        validationIsSuccess = false
        validationMessage = nil
        token = ""
        let config = PixelaAccountConfig(username: username, isVerified: false)
        config.save()
        try? KeychainStore.deleteToken()
        savedConfig = config
    }
}
