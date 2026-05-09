import Foundation
import SwiftData

@Model
final class ActivitySyncRecord {
    var activityType: String
    var lastSentDate: Date
    var lastSentValue: Double
    var lastSentDelta: Double
    var lastSyncedAt: Date

    init(activityType: ActivityType) {
        self.activityType = activityType.rawValue
        self.lastSentDate = .distantPast
        self.lastSentValue = 0
        self.lastSentDelta = 0
        self.lastSyncedAt = .distantPast
    }

    var requiresReset: Bool {
        !Calendar.current.isDateInToday(lastSentDate)
    }

    var type: ActivityType? {
        ActivityType(rawValue: activityType)
    }
}

struct ActivitySyncRecordDTO: Sendable {
    let activityType: String
    let lastSentDate: Date
    let lastSentValue: Double
    let lastSentDelta: Double

    var requiresReset: Bool {
        !Calendar.current.isDateInToday(lastSentDate)
    }
}
