import Foundation
import BackgroundTasks

final class BackgroundTaskManager: Sendable {
    static let shared = BackgroundTaskManager()

    private static let refreshTaskID = "com.pixela.links.refresh"

    func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskID,
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleNextRefresh()

        let syncTask = Task {
            await BackgroundSyncCoordinator.shared.sync(
                types: ActivityType.bgRefreshTypes
            )
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            syncTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
