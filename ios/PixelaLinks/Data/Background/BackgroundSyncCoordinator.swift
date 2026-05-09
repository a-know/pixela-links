import Foundation
import SwiftData

actor BackgroundSyncCoordinator {
    static let shared = BackgroundSyncCoordinator()

    private var activeSyncs: Set<String> = []
    private var storage: LocalStorageRepository?
    private var pixelaRepo: any PixelaRepository = PixelaRepositoryImpl()
    private var dataSources: [ActivityType: any ActivityDataSource] = [:]

    func configure(modelContainer: ModelContainer) {
        self.storage = LocalStorageRepository(modelContainer: modelContainer)
    }

    func register(dataSource: any ActivityDataSource) {
        dataSources[dataSource.type] = dataSource
    }

    func sync(types: [ActivityType]) async {
        let pending = types.filter { !activeSyncs.contains($0.rawValue) }
        guard !pending.isEmpty else { return }
        activeSyncs.formUnion(pending.map(\.rawValue))
        defer { activeSyncs.subtract(pending.map(\.rawValue)) }

        await withTaskGroup(of: Void.self) { group in
            for type in pending {
                group.addTask { await self.syncOne(type) }
            }
        }
    }

    private func syncOne(_ type: ActivityType) async {
        guard let storage else { return }
        guard let configDTO = try? await storage.configDTO(for: type),
              configDTO.isEnabled,
              !configDTO.pixelaGraphID.isEmpty else { return }
        guard let source = dataSources[type] else { return }

        do {
            let total = try await source.fetchTodayTotal()
            let recordDTO = try? await storage.recordDTO(for: type)
            let delta: Double
            if let recordDTO, !recordDTO.requiresReset {
                delta = total - recordDTO.lastSentValue
            } else {
                delta = total
            }
            guard delta > 0 else { return }

            try await pixelaRepo.addPixel(delta: delta, graphID: configDTO.pixelaGraphID)
            try? await storage.updateRecord(type: type, value: total)
        } catch let error as PixelaError {
            let syncError = ActivitySyncError(
                activityType: type,
                statusCode: error.statusCode,
                message: error.localizedDescription
            )
            try? await storage.recordError(syncError)
        } catch {
            let syncError = ActivitySyncError(
                activityType: type,
                statusCode: nil,
                message: error.localizedDescription
            )
            try? await storage.recordError(syncError)
        }
    }
}
