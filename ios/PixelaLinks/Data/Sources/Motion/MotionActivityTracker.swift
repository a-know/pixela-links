import CoreMotion
import Foundation

@MainActor
final class MotionActivityTracker {
    static let shared = MotionActivityTracker()

    private let altimeter = CMAltimeter()
    private let altimeterQueue = OperationQueue()

    private var lastRelativeAltitude: Double?
    private(set) var cumulativeGainMeters: Double = 0
    private var resetDateString = ""

    func start() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: altimeterQueue) { [weak self] data, error in
            guard let data, error == nil else { return }
            let relative = data.relativeAltitude.doubleValue
            Task { @MainActor [weak self] in
                self?.handleAltitude(relative)
            }
        }
    }

    private func handleAltitude(_ relative: Double) {
        resetIfDayChanged()
        if let last = lastRelativeAltitude {
            let diff = relative - last
            if diff > 0 { cumulativeGainMeters += diff }
        }
        lastRelativeAltitude = relative
    }

    private func resetIfDayChanged() {
        let today = DateFormatter.pixelaDate.string(from: .now)
        guard resetDateString != today else { return }
        resetDateString = today
        cumulativeGainMeters = 0
        lastRelativeAltitude = nil
    }

    func makeDataSources() -> [any ActivityDataSource] {
        [
            MotionDataSource(type: .cumulativeElevationGain, tracker: self),
        ]
    }
}

struct MotionDataSource: ActivityDataSource, @unchecked Sendable {
    let type: ActivityType
    private let tracker: MotionActivityTracker

    fileprivate init(type: ActivityType, tracker: MotionActivityTracker) {
        self.type = type
        self.tracker = tracker
    }

    func requestAuthorization() async throws {}

    func fetchTodayTotal() async throws -> Double {
        switch type {
        case .cumulativeElevationGain:
            return await MainActor.run { tracker.cumulativeGainMeters }
        default:
            return 0
        }
    }
}
