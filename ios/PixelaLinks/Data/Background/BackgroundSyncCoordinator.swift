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

    func purgeOldErrors() async {
        guard let storage else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        try? await storage.purgeErrors(before: cutoff)
    }

    private func syncOne(_ type: ActivityType) async {
        guard let storage else { return }
        guard let configDTO = try? await storage.configDTO(for: type),
              configDTO.isEnabled,
              !configDTO.pixelaGraphID.isEmpty else { return }
        guard let source = dataSources[type] else { return }

        do {
            let rawTotal = try await source.fetchTodayTotal()

            if type.isAverageMetric {
                guard rawTotal > 0 else { return }
                try await withTimeoutRetry(maxRetries: 5) {
                    try await self.pixelaRepo.updatePixel(value: rawTotal, graphID: configDTO.pixelaGraphID)
                }
                try? await storage.updateRecord(type: type, value: rawTotal, delta: rawTotal)
                try? await storage.recordSendHistory(type: type, delta: rawTotal, value: rawTotal)
            } else {
                let total = type.isIntegerValue ? rawTotal.rounded() : rawTotal
                let recordDTO = try? await storage.recordDTO(for: type)
                let rawDelta: Double
                if let recordDTO, !recordDTO.requiresReset {
                    rawDelta = total - recordDTO.lastSentValue
                } else {
                    rawDelta = total
                }
                let delta = type.isIntegerValue ? rawDelta.rounded() : rawDelta
                guard delta > 0, delta.rounded() > 0 else { return }

                try await withTimeoutRetry(maxRetries: 5) {
                    try await self.pixelaRepo.addPixel(delta: delta, graphID: configDTO.pixelaGraphID)
                }
                try? await storage.updateRecord(type: type, value: total, delta: delta)
                try? await storage.recordSendHistory(type: type, delta: delta, value: total)
            }
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

    private func withTimeoutRetry(maxRetries: Int, operation: () async throws -> Void) async throws {
        for attempt in 0...maxRetries {
            do {
                try await operation()
                return
            } catch let urlError as URLError where urlError.code == .timedOut {
                if attempt == maxRetries { throw urlError }
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機してリトライ
            }
        }
    }
}
