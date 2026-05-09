import CoreLocation
import Foundation

final class LocationBackgroundManager: NSObject {
    static let shared = LocationBackgroundManager()

    private let locationManager = CLLocationManager()
    // Written/read on main thread (CLLocationManager delegate)
    private(set) var locationChangeCount: Double = 0
    private(set) var outsideMinutes: Double = 0
    private var lastLocationDate: Date?
    private var resetDateString = ""

    func start() {
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.startMonitoringSignificantLocationChanges()
    }

    func makeDataSources() -> [any ActivityDataSource] {
        [
            LocationDataSource(type: .significantLocationChangeCount, manager: self),
            LocationDataSource(type: .timeOutside, manager: self),
        ]
    }

    private func resetIfDayChanged() {
        let today = DateFormatter.pixelaDate.string(from: .now)
        guard resetDateString != today else { return }
        resetDateString = today
        locationChangeCount = 0
        outsideMinutes = 0
        lastLocationDate = nil
    }
}

extension LocationBackgroundManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resetIfDayChanged()

        let now = Date.now
        if let last = lastLocationDate {
            let elapsed = now.timeIntervalSince(last)
            // Accumulate only within continuous outdoor sessions (2-hour gap threshold)
            if elapsed < 2 * 3600 {
                outsideMinutes += elapsed / 60
            }
        }
        lastLocationDate = now
        locationChangeCount += 1

        Task {
            await BackgroundSyncCoordinator.shared.sync(
                types: [.significantLocationChangeCount, .timeOutside]
            )
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

struct LocationDataSource: ActivityDataSource, @unchecked Sendable {
    let type: ActivityType
    private let manager: LocationBackgroundManager

    fileprivate init(type: ActivityType, manager: LocationBackgroundManager) {
        self.type = type
        self.manager = manager
    }

    func requestAuthorization() async throws {}

    func fetchTodayTotal() async throws -> Double {
        switch type {
        case .significantLocationChangeCount:
            return await MainActor.run { manager.locationChangeCount }
        case .timeOutside:
            return await MainActor.run { manager.outsideMinutes }
        default:
            return 0
        }
    }
}
