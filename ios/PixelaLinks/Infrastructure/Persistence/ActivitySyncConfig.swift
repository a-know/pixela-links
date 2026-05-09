import Foundation
import SwiftData

@Model
final class ActivitySyncConfig {
    var activityType: String
    var isEnabled: Bool
    var pixelaGraphID: String
    var createdAt: Date
    var updatedAt: Date

    init(activityType: ActivityType, graphID: String) {
        self.activityType = activityType.rawValue
        self.isEnabled = true
        self.pixelaGraphID = graphID
        self.createdAt = .now
        self.updatedAt = .now
    }

    var type: ActivityType? {
        ActivityType(rawValue: activityType)
    }
}

struct ActivitySyncConfigDTO: Sendable {
    let activityType: String
    let isEnabled: Bool
    let pixelaGraphID: String
}
