import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ActivityDetailViewModel {
    let activityType: ActivityType
    var isEnabled: Bool = false
    var graphID: String = ""

    private var hasLoaded = false

    init(activityType: ActivityType) {
        self.activityType = activityType
    }

    func loadIfNeeded(from context: ModelContext) {
        guard !hasLoaded else { return }
        hasLoaded = true
        let rawValue = activityType.rawValue
        let descriptor = FetchDescriptor<ActivitySyncConfig>(
            predicate: #Predicate { $0.activityType == rawValue }
        )
        guard let config = try? context.fetch(descriptor).first else { return }
        isEnabled = config.isEnabled
        graphID = config.pixelaGraphID
    }

    func save(to context: ModelContext) {
        guard hasLoaded else { return }
        let rawValue = activityType.rawValue
        let descriptor = FetchDescriptor<ActivitySyncConfig>(
            predicate: #Predicate { $0.activityType == rawValue }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.isEnabled = isEnabled
            existing.pixelaGraphID = graphID
            existing.updatedAt = .now
        } else if isEnabled || !graphID.isEmpty {
            let config = ActivitySyncConfig(activityType: activityType, graphID: graphID)
            config.isEnabled = isEnabled
            context.insert(config)
        }
        try? context.save()
    }
}
