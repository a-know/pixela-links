import Foundation
import SwiftData

@ModelActor
actor LocalStorageRepository {

    // MARK: - Config

    func configDTO(for type: ActivityType) throws -> ActivitySyncConfigDTO? {
        let rawValue = type.rawValue
        let descriptor = FetchDescriptor<ActivitySyncConfig>(
            predicate: #Predicate { $0.activityType == rawValue }
        )
        return try modelContext.fetch(descriptor).first.map {
            ActivitySyncConfigDTO(
                activityType: $0.activityType,
                isEnabled: $0.isEnabled,
                pixelaGraphID: $0.pixelaGraphID
            )
        }
    }

    func upsertConfig(type: ActivityType, graphID: String, isEnabled: Bool) throws {
        let rawValue = type.rawValue
        let descriptor = FetchDescriptor<ActivitySyncConfig>(
            predicate: #Predicate { $0.activityType == rawValue }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.pixelaGraphID = graphID
            existing.isEnabled = isEnabled
            existing.updatedAt = .now
        } else {
            let config = ActivitySyncConfig(activityType: type, graphID: graphID)
            config.isEnabled = isEnabled
            modelContext.insert(config)
        }
        try modelContext.save()
    }

    // MARK: - Record

    func recordDTO(for type: ActivityType) throws -> ActivitySyncRecordDTO? {
        let rawValue = type.rawValue
        let descriptor = FetchDescriptor<ActivitySyncRecord>(
            predicate: #Predicate { $0.activityType == rawValue }
        )
        return try modelContext.fetch(descriptor).first.map {
            ActivitySyncRecordDTO(
                activityType: $0.activityType,
                lastSentDate: $0.lastSentDate,
                lastSentValue: $0.lastSentValue,
                lastSentDelta: $0.lastSentDelta
            )
        }
    }

    func updateRecord(type: ActivityType, value: Double, delta: Double) throws {
        let rawValue = type.rawValue
        let descriptor = FetchDescriptor<ActivitySyncRecord>(
            predicate: #Predicate { $0.activityType == rawValue }
        )
        let now = Date.now
        if let existing = try modelContext.fetch(descriptor).first {
            existing.lastSentDate = now
            existing.lastSentValue = value
            existing.lastSentDelta = delta
            existing.lastSyncedAt = now
        } else {
            let record = ActivitySyncRecord(activityType: type)
            record.lastSentDate = now
            record.lastSentValue = value
            record.lastSentDelta = delta
            record.lastSyncedAt = now
            modelContext.insert(record)
        }
        try modelContext.save()
    }

    // MARK: - Send History

    func recordSendHistory(type: ActivityType, delta: Double, value: Double) throws {
        let history = ActivitySendHistory(activityType: type, delta: delta, value: value)
        modelContext.insert(history)
        let rawValue = type.rawValue
        let descriptor = FetchDescriptor<ActivitySendHistory>(
            predicate: #Predicate { $0.activityType == rawValue },
            sortBy: [SortDescriptor(\.sentAt, order: .reverse)]
        )
        let all = try modelContext.fetch(descriptor)
        if all.count > 100 {
            all.dropFirst(100).forEach { modelContext.delete($0) }
        }
        try modelContext.save()
    }

    // MARK: - Errors

    func recordError(_ error: ActivitySyncError) throws {
        modelContext.insert(error)
        try modelContext.save()
    }

    func errorCount(for type: ActivityType, dateString: String) throws -> Int {
        let rawValue = type.rawValue
        let descriptor = FetchDescriptor<ActivitySyncError>(
            predicate: #Predicate { $0.activityType == rawValue && $0.dateString == dateString }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func recentErrors(for type: ActivityType, limit: Int = 30) throws -> [ActivitySyncError] {
        let rawValue = type.rawValue
        var descriptor = FetchDescriptor<ActivitySyncError>(
            predicate: #Predicate { $0.activityType == rawValue },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func purgeErrors(before date: Date) throws {
        let descriptor = FetchDescriptor<ActivitySyncError>(
            predicate: #Predicate { $0.occurredAt < date }
        )
        try modelContext.fetch(descriptor).forEach { modelContext.delete($0) }
        try modelContext.save()
    }
}
