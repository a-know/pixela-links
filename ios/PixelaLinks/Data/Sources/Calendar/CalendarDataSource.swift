import EventKit
import Foundation

struct CalendarDataSource: ActivityDataSource {
    let type: ActivityType

    func requestAuthorization() async throws {
        let store = EKEventStore()
        switch type {
        case .calendarEventCount:
            try await store.requestFullAccessToEvents()
        case .completedReminderCount, .createdReminderCount:
            try await store.requestFullAccessToReminders()
        default:
            break
        }
    }

    func fetchTodayTotal() async throws -> Double {
        guard let today = Calendar.current.dateInterval(of: .day, for: .now) else { return 0 }
        let store = EKEventStore()

        switch type {
        case .calendarEventCount:
            guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return 0 }
            return countEvents(in: today, store: store)

        case .completedReminderCount:
            guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return 0 }
            return try await countCompletedReminders(in: today, store: store)

        case .createdReminderCount:
            guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return 0 }
            return try await countCreatedReminders(in: today, store: store)

        default:
            return 0
        }
    }

    private func countEvents(in day: DateInterval, store: EKEventStore) -> Double {
        let cals = store.calendars(for: .event)
        let pred = store.predicateForEvents(withStart: day.start, end: day.end, calendars: cals)
        return Double(store.events(matching: pred).count)
    }

    private func countCompletedReminders(
        in day: DateInterval,
        store: EKEventStore
    ) async throws -> Double {
        let pred = store.predicateForCompletedReminders(
            withCompletionDateStarting: day.start,
            ending: day.end,
            calendars: nil
        )
        return try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: pred) { reminders in
                continuation.resume(returning: Double(reminders?.count ?? 0))
            }
        }
    }

    private func countCreatedReminders(
        in day: DateInterval,
        store: EKEventStore
    ) async throws -> Double {
        let pred = store.predicateForReminders(in: nil)
        return try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: pred) { reminders in
                let count = reminders?.filter { reminder in
                    guard let created = reminder.creationDate else { return false }
                    return day.contains(created)
                }.count ?? 0
                continuation.resume(returning: Double(count))
            }
        }
    }
}
