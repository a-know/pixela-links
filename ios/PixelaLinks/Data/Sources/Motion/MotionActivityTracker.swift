import CoreMotion
import Foundation

@MainActor
final class MotionActivityTracker {
    static let shared = MotionActivityTracker()

    private let altimeter = CMAltimeter()
    private let altimeterQueue = OperationQueue()

    private var lastRelativeAltitude: Double?
    private(set) var cumulativeGainMeters: Double = 0

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
        if let last = lastRelativeAltitude {
            let diff = relative - last
            if diff > 0 { cumulativeGainMeters += diff }
        }
        lastRelativeAltitude = relative
    }

    func queryAutomotiveMinutes() async throws -> Double {
        guard CMMotionActivityManager.isActivityAvailable() else { return 0 }
        guard let today = Calendar.current.dateInterval(of: .day, for: .now) else { return 0 }

        let manager = CMMotionActivityManager()
        let activities: [CMMotionActivity] = try await withCheckedThrowingContinuation { cont in
            manager.queryActivityStarting(from: today.start, to: today.end, to: .main) { acts, err in
                if let err { cont.resume(throwing: err) }
                else { cont.resume(returning: acts ?? []) }
            }
        }

        return automotiveMinutes(from: activities, dayEnd: today.end)
    }

    private func automotiveMinutes(from activities: [CMMotionActivity], dayEnd: Date) -> Double {
        guard !activities.isEmpty else { return 0 }
        var total = 0.0
        for (i, activity) in activities.enumerated() {
            guard activity.automotive else { continue }
            let start = activity.startDate
            let end = i + 1 < activities.count
                ? activities[i + 1].startDate
                : min(dayEnd, Date.now)
            let duration = end.timeIntervalSince(start)
            if duration > 0 { total += duration }
        }
        return total / 60
    }

    func makeDataSources() -> [any ActivityDataSource] {
        [
            MotionDataSource(type: .cumulativeElevationGain, tracker: self),
            MotionDataSource(type: .automotiveTime, tracker: self),
            MotionDataSource(type: .automotiveDistance, tracker: self),
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
        case .automotiveTime:
            return try await tracker.queryAutomotiveMinutes()
        case .automotiveDistance:
            // Phase 5: GPS + motion fusion for true distance
            let minutes = try await tracker.queryAutomotiveMinutes()
            return minutes / 60 * 30 // rough estimate: 30 km/h average city speed
        default:
            return 0
        }
    }
}
