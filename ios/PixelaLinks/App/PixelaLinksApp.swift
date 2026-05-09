import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct PixelaLinksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    let sharedModelContainer: ModelContainer = {
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
                .task {
                    AppContainer.shared.configure(modelContainer: sharedModelContainer)
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                AppContainer.shared.flushAndSync()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundTaskManager.shared.registerTasks()
        // Initialize Bluetooth manager early for Core Bluetooth state restoration
        _ = BluetoothBackgroundManager.shared
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
