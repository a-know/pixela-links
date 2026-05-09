import Foundation

enum NetworkClient {
    static let backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.pixela.links.upload"
        )
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config)
    }()

    static let foregroundSession = URLSession.shared
}
