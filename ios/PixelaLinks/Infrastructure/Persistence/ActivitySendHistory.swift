import Foundation
import SwiftData

@Model
final class ActivitySendHistory {
    var activityType: String
    var sentAt: Date
    var sentDelta: Double
    var sentValue: Double

    init(activityType: ActivityType, delta: Double, value: Double) {
        self.activityType = activityType.rawValue
        self.sentAt = .now
        self.sentDelta = delta
        self.sentValue = value
    }

    var type: ActivityType? {
        ActivityType(rawValue: activityType)
    }
}
