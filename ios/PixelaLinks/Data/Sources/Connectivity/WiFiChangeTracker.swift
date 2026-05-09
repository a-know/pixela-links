import Network
import Foundation

final class WiFiChangeTracker {
    static let shared = WiFiChangeTracker()

    private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private var wasConnected = false
    // Written/read on main thread only
    private(set) var changeCount: Double = 0
    private var resetDateString = ""

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                self.resetIfDayChanged()
                let connected = path.status == .satisfied
                if connected && !self.wasConnected {
                    self.changeCount += 1
                }
                self.wasConnected = connected
            }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    var dataSource: any ActivityDataSource {
        WiFiDataSource(tracker: self)
    }

    private func resetIfDayChanged() {
        let today = DateFormatter.pixelaDate.string(from: .now)
        guard resetDateString != today else { return }
        resetDateString = today
        changeCount = 0
        wasConnected = false
    }
}

struct WiFiDataSource: ActivityDataSource, @unchecked Sendable {
    let type: ActivityType = .wifiNetworkChangeCount
    private let tracker: WiFiChangeTracker

    fileprivate init(tracker: WiFiChangeTracker) {
        self.tracker = tracker
    }

    func requestAuthorization() async throws {}

    func fetchTodayTotal() async throws -> Double {
        await MainActor.run { tracker.changeCount }
    }
}
