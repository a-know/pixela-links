import Foundation

protocol ActivityDataSource: Sendable {
    var type: ActivityType { get }
    func requestAuthorization() async throws
    func fetchTodayTotal() async throws -> Double
    func fetchDailyHistory(from: Date, to: Date) async throws -> [(date: Date, value: Double)]
}

extension ActivityDataSource {
    func fetchDailyHistory(from: Date, to: Date) async throws -> [(date: Date, value: Double)] { [] }
}
