import CoreLocation
import Foundation

final class LocationBackgroundManager: NSObject {
    static let shared = LocationBackgroundManager()

    private let locationManager = CLLocationManager()
    private(set) var locationChangeCount: Double = 0
    private(set) var outsideMinutes: Double = 0
    private var resetDateString = ""

    // MARK: - Home location (UserDefaults)

    private static let homeRegionID  = "com.pixela.links.home"
    private static let homeRadius: CLLocationDistance = 100
    private static let latKey        = "home_latitude"
    private static let lonKey        = "home_longitude"
    private static let departureKey  = "home_departure_time"

    var homeCoordinate: CLLocationCoordinate2D? {
        let lat = UserDefaults.standard.double(forKey: Self.latKey)
        let lon = UserDefaults.standard.double(forKey: Self.lonKey)
        // UserDefaults returns 0.0 for missing keys; treat (0,0) as unset
        guard lat != 0 || lon != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var departureDate: Date? {
        let ts = UserDefaults.standard.double(forKey: Self.departureKey)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    // 今日の外出時間合計（帰宅済みセッション＋現在進行中セッション）
    var currentOutsideMinutes: Double {
        var total = outsideMinutes
        guard let departure = departureDate else { return total }
        let now = Date.now
        guard let today = Calendar.current.dateInterval(of: .day, for: now) else { return total }
        // 日をまたいでいる場合は今日の0:00を起点にする
        let effectiveDeparture = max(departure, today.start)
        let elapsed = now.timeIntervalSince(effectiveDeparture)
        if elapsed > 0 { total += elapsed / 60 }
        return total
    }

    // MARK: - Coordinate request continuation

    private var coordinateContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    // MARK: - Setup

    func start() {
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.startMonitoringSignificantLocationChanges()
        if let coord = homeCoordinate {
            activateGeofence(at: coord)
        }
    }

    func makeDataSources() -> [any ActivityDataSource] {
        [
            LocationDataSource(type: .significantLocationChangeCount, manager: self),
            LocationDataSource(type: .timeOutside, manager: self),
        ]
    }

    // MARK: - Home location management

    func setHomeLocation(_ coordinate: CLLocationCoordinate2D) {
        UserDefaults.standard.set(coordinate.latitude, forKey: Self.latKey)
        UserDefaults.standard.set(coordinate.longitude, forKey: Self.lonKey)
        activateGeofence(at: coordinate)
    }

    func removeHomeLocation() {
        stopGeofence()
        UserDefaults.standard.removeObject(forKey: Self.latKey)
        UserDefaults.standard.removeObject(forKey: Self.lonKey)
        UserDefaults.standard.removeObject(forKey: Self.departureKey)
        outsideMinutes = 0
        resetDateString = ""
    }

    // 現在地を一度だけ取得する
    func requestCurrentCoordinate() async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { continuation in
            coordinateContinuation = continuation
            locationManager.requestLocation()
        }
    }

    // MARK: - Private

    private func activateGeofence(at coordinate: CLLocationCoordinate2D) {
        stopGeofence()
        let region = CLCircularRegion(
            center: coordinate,
            radius: Self.homeRadius,
            identifier: Self.homeRegionID
        )
        region.notifyOnEntry = true
        region.notifyOnExit  = true
        locationManager.startMonitoring(for: region)
    }

    private func stopGeofence() {
        locationManager.monitoredRegions
            .filter { $0.identifier == Self.homeRegionID }
            .forEach { locationManager.stopMonitoring(for: $0) }
    }

    private func resetIfDayChanged() {
        let today = DateFormatter.pixelaDate.string(from: .now)
        guard resetDateString != today else { return }
        resetDateString = today
        locationChangeCount = 0
        outsideMinutes = 0
        // departureDate はそのまま保持し currentOutsideMinutes 内でクランプする
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationBackgroundManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 現在地リクエストへの応答
        if let continuation = coordinateContinuation, let location = locations.last {
            coordinateContinuation = nil
            continuation.resume(returning: location.coordinate)
            return
        }
        // Significant Location Change → locationChangeCount のみ更新
        resetIfDayChanged()
        locationChangeCount += 1
        Task {
            await BackgroundSyncCoordinator.shared.sync(
                types: [.significantLocationChangeCount, .timeOutside]
            )
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == Self.homeRegionID else { return }
        resetIfDayChanged()
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Self.departureKey)
        Task {
            await BackgroundSyncCoordinator.shared.sync(types: [.timeOutside])
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == Self.homeRegionID else { return }
        resetIfDayChanged()
        // 帰宅したので進行中セッションを確定してリセット
        if let departure = departureDate,
           let today = Calendar.current.dateInterval(of: .day, for: .now) {
            let effectiveDeparture = max(departure, today.start)
            let elapsed = Date.now.timeIntervalSince(effectiveDeparture)
            if elapsed > 0 { outsideMinutes += elapsed / 60 }
        }
        UserDefaults.standard.removeObject(forKey: Self.departureKey)
        Task {
            await BackgroundSyncCoordinator.shared.sync(types: [.timeOutside])
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let continuation = coordinateContinuation {
            coordinateContinuation = nil
            continuation.resume(throwing: error)
        }
    }
}

// MARK: - LocationDataSource

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
            return await MainActor.run { manager.currentOutsideMinutes }
        default:
            return 0
        }
    }
}
