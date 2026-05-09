import UIKit
import SwiftData
import Photos
import EventKit

@MainActor
final class AppContainer {
    static let shared = AppContainer()
    private var isConfigured = false

    func configure(modelContainer: ModelContainer) {
        guard !isConfigured else { return }
        isConfigured = true

        Task {
            await BackgroundSyncCoordinator.shared.configure(modelContainer: modelContainer)
            await registerAllDataSources()
            startBackgroundManagers()
            BackgroundTaskManager.shared.scheduleNextRefresh()
        }
    }

    func flushAndSync() {
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "pixela-flush") {}
        Task {
            MemoryOnlyActivityTracker.shared.flush()
            await BackgroundSyncCoordinator.shared.sync(types: ActivityType.memoryOnlyTypes)
            UIApplication.shared.endBackgroundTask(bgTask)
        }
    }

    // MARK: - Authorization

    static func requestAuthorization(for type: ActivityType) async {
        switch type.category {
        case .photoMedia:
            guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined else { return }
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

        case .calendarTask:
            let store = EKEventStore()
            if type == .calendarEventCount {
                try? await store.requestFullAccessToEvents()
            } else {
                try? await store.requestFullAccessToReminders()
            }

        default:
            break // HealthKit, Location, Motion handle auth in their own managers
        }
    }

    // MARK: - Private

    private func registerAllDataSources() async {
        // HealthKit (15 types)
        for type in ActivityType.healthKitTypes {
            await BackgroundSyncCoordinator.shared.register(dataSource: HealthKitDataSource(type: type))
        }

        // Memory-only (5 types): call, audio, battery, orientation
        let memoryTracker = MemoryOnlyActivityTracker.shared
        memoryTracker.start()
        for source in memoryTracker.makeDataSources() {
            await BackgroundSyncCoordinator.shared.register(dataSource: source)
        }

        // Location (2 types): significantLocationChange, timeOutside
        for source in LocationBackgroundManager.shared.makeDataSources() {
            await BackgroundSyncCoordinator.shared.register(dataSource: source)
        }

        // Bluetooth (1 type)
        await BackgroundSyncCoordinator.shared.register(
            dataSource: BluetoothBackgroundManager.shared.makeDataSource()
        )

        // Photos (3 types)
        for type in [ActivityType.photoLibraryAddCount, .screenshotCount, .videoRecordingDuration] {
            await BackgroundSyncCoordinator.shared.register(dataSource: PhotosDataSource(type: type))
        }

        // Calendar & Reminders (2 types)
        for type in [ActivityType.calendarEventCount, .completedReminderCount] {
            await BackgroundSyncCoordinator.shared.register(dataSource: CalendarDataSource(type: type))
        }

        // Motion: elevation gain, automotive time/distance (3 types)
        let motionTracker = MotionActivityTracker.shared
        for source in motionTracker.makeDataSources() {
            await BackgroundSyncCoordinator.shared.register(dataSource: source)
        }

        // WiFi change count (1 type)
        await BackgroundSyncCoordinator.shared.register(
            dataSource: WiFiChangeTracker.shared.dataSource
        )
    }

    private func startBackgroundManagers() {
        HealthKitBackgroundManager.shared.start()
        LocationBackgroundManager.shared.start()
        _ = BluetoothBackgroundManager.shared
        MotionActivityTracker.shared.start()
        WiFiChangeTracker.shared.start()
    }
}
