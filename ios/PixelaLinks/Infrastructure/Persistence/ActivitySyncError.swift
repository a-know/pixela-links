import Foundation
import SwiftData

@Model
final class ActivitySyncError {
    var activityType: String
    var occurredAt: Date
    var dateString: String  // "yyyyMMdd" — 日別集計を高速に行うためのフィールド
    var statusCode: Int?
    var message: String

    init(activityType: ActivityType, statusCode: Int?, message: String) {
        self.activityType = activityType.rawValue
        let now = Date.now
        self.occurredAt = now
        self.dateString = DateFormatter.pixelaDate.string(from: now)
        self.statusCode = statusCode
        self.message = message
    }

    var type: ActivityType? {
        ActivityType(rawValue: activityType)
    }
}
