import CoreLocation
import Foundation

final class LocationBackgroundManager: NSObject {
    static let shared = LocationBackgroundManager()

    private let locationManager = CLLocationManager()
    // Only written/read on main thread via CLLocationManager delegate
    private(set) var locationChangeCount: Double = 0

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
}

extension LocationBackgroundManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
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
            return 0 // Phase 4: implement via geofencing / region monitoring
        default:
            return 0
        }
    }
}
