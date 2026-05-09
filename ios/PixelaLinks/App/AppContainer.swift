import UIKit
import SwiftData

@MainActor
final class AppContainer {
    static let shared = AppContainer()
    private var isConfigured = false

    func configure(modelContainer: ModelContainer) {
        guard !isConfigured else { return }
        isConfigured = true

        Task {
            await BackgroundSyncCoordinator.shared.configure(modelContainer: modelContainer)

            for type in ActivityType.healthKitTypes {
                await BackgroundSyncCoordinator.shared.register(dataSource: HealthKitDataSource(type: type))
            }

            let tracker = MemoryOnlyActivityTracker.shared
            tracker.start()
            for source in tracker.makeDataSources() {
                await BackgroundSyncCoordinator.shared.register(dataSource: source)
            }

            LocationBackgroundManager.shared.start()
            for source in LocationBackgroundManager.shared.makeDataSources() {
                await BackgroundSyncCoordinator.shared.register(dataSource: source)
            }

            _ = BluetoothBackgroundManager.shared
            await BackgroundSyncCoordinator.shared.register(
                dataSource: BluetoothBackgroundManager.shared.makeDataSource()
            )

            HealthKitBackgroundManager.shared.start()
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
}
