import Foundation

protocol ActivityDataSource: Sendable {
    var type: ActivityType { get }
    func requestAuthorization() async throws
    func fetchTodayTotal() async throws -> Double
}
