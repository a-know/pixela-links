import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct PixelaLinksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ActivitySyncConfig.self,
            ActivitySyncRecord.self,
            ActivitySyncError.self,
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("ModelContainer の初期化に失敗しました: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundTaskManager.shared.registerTasks()
        return true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
