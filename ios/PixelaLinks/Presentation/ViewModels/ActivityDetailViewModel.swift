import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ActivityDetailViewModel {
    let activityType: ActivityType
    var isEnabled: Bool = false
    var selectedGraphID: String = ""

    var graphs: [PixelaGraph] = []
    var isLoadingGraphs: Bool = false
    var graphsError: String? = nil

    var showingCreateGraph: Bool = false
    var showingBackfill: Bool = false
    var isBackfillCompleted: Bool = false

    private var hasLoaded = false
    private let pixelaRepo: any PixelaRepository = PixelaRepositoryImpl()

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
        selectedGraphID = config.pixelaGraphID
        isBackfillCompleted = config.isBackfillCompleted
    }

    func loadGraphs() async {
        isLoadingGraphs = true
        graphsError = nil
        do {
            graphs = try await pixelaRepo.fetchGraphs()
        } catch {
            graphsError = "グラフ一覧の取得に失敗しました"
            graphs = []
        }
        isLoadingGraphs = false
    }

    func createGraph(id: String, name: String, unit: String, type: String, color: String, timezone: String, description: String, isSecret: Bool, context: ModelContext) async throws {
        let tz   = timezone.isEmpty    ? nil : timezone
        let desc = description.isEmpty ? nil : description
        try await pixelaRepo.createGraph(id: id, name: name, unit: unit, type: type, color: color, timezone: tz, description: desc, isSecret: isSecret)
        await loadGraphs()
        selectedGraphID = id
        save(to: context)
    }

    func markBackfillCompleted(context: ModelContext) {
        let rawValue = activityType.rawValue
        let descriptor = FetchDescriptor<ActivitySyncConfig>(
            predicate: #Predicate { $0.activityType == rawValue }
        )
        if let config = try? context.fetch(descriptor).first {
            config.isBackfillCompleted = true
            try? context.save()
        }
        isBackfillCompleted = true
    }

    func save(to context: ModelContext) {
        guard hasLoaded else { return }
        let rawValue = activityType.rawValue
        let descriptor = FetchDescriptor<ActivitySyncConfig>(
            predicate: #Predicate { $0.activityType == rawValue }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.isEnabled = isEnabled
            existing.pixelaGraphID = selectedGraphID
            existing.updatedAt = .now
        } else if isEnabled || !selectedGraphID.isEmpty {
            let config = ActivitySyncConfig(activityType: activityType, graphID: selectedGraphID)
            config.isEnabled = isEnabled
            context.insert(config)
        }
        try? context.save()
    }
}
