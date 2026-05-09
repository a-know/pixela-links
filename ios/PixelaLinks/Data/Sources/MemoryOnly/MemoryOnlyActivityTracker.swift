import Foundation
import CallKit
import AVFoundation
import UIKit

@MainActor
final class MemoryOnlyActivityTracker: NSObject {
    static let shared = MemoryOnlyActivityTracker()

    private(set) var callCount: Double = 0
    private(set) var callDurationMinutes: Double = 0
    private(set) var earphoneMinutes: Double = 0
    private(set) var chargingMinutes: Double = 0
    private(set) var orientationChanges: Double = 0

    private var callStartDate: Date?
    private var earphoneConnectedSince: Date?
    private var chargingStartDate: Date?

    private let callObserver = CXCallObserver()

    func start() {
        callObserver.setDelegate(self, queue: .main)

        NotificationCenter.default.addObserver(
            self, selector: #selector(audioRouteChanged(_:)),
            name: AVAudioSession.routeChangeNotification, object: nil
        )
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification, object: nil
        )

        checkInitialAudioRoute()
        checkInitialBatteryState()
    }

    func flush() {
        let now = Date.now
        if let start = earphoneConnectedSince {
            earphoneMinutes += now.timeIntervalSince(start) / 60
            earphoneConnectedSince = now
        }
        if let start = chargingStartDate {
            chargingMinutes += now.timeIntervalSince(start) / 60
            chargingStartDate = now
        }
        if let start = callStartDate {
            callDurationMinutes += now.timeIntervalSince(start) / 60
            callStartDate = now
        }
    }

    func makeDataSources() -> [any ActivityDataSource] {
        [
            MemoryOnlyDataSource(type: .callCount, tracker: self),
            MemoryOnlyDataSource(type: .callDuration, tracker: self),
            MemoryOnlyDataSource(type: .earphoneUsageTime, tracker: self),
            MemoryOnlyDataSource(type: .chargingTime, tracker: self),
            MemoryOnlyDataSource(type: .orientationChangeCount, tracker: self),
        ]
    }

    // MARK: - Private helpers

    private func checkInitialAudioRoute() {
        if isEarphoneRoute(AVAudioSession.sharedInstance().currentRoute) {
            earphoneConnectedSince = .now
        }
    }

    private func checkInitialBatteryState() {
        let state = UIDevice.current.batteryState
        if state == .charging || state == .full {
            chargingStartDate = .now
        }
    }

    private func isEarphoneRoute(_ route: AVAudioSessionRouteDescription) -> Bool {
        route.outputs.contains {
            $0.portType == .headphones
                || $0.portType == .bluetoothA2DP
                || $0.portType == .bluetoothHFP
        }
    }

    @objc private func audioRouteChanged(_ notification: Notification) {
        let session = AVAudioSession.sharedInstance()
        let hasEarphone = isEarphoneRoute(session.currentRoute)

        if hasEarphone && earphoneConnectedSince == nil {
            earphoneConnectedSince = .now
        } else if !hasEarphone, let start = earphoneConnectedSince {
            earphoneMinutes += Date.now.timeIntervalSince(start) / 60
            earphoneConnectedSince = nil
        }
    }

    @objc private func batteryStateChanged() {
        let state = UIDevice.current.batteryState
        let isCharging = state == .charging || state == .full

        if isCharging && chargingStartDate == nil {
            chargingStartDate = .now
        } else if !isCharging, let start = chargingStartDate {
            chargingMinutes += Date.now.timeIntervalSince(start) / 60
            chargingStartDate = nil
        }
    }

    @objc private func orientationDidChange() {
        orientationChanges += 1
    }
}

extension MemoryOnlyActivityTracker: CXCallObserverDelegate {
    nonisolated func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        Task { @MainActor in
            if call.hasConnected && !call.hasEnded {
                self.callStartDate = .now
            } else if call.hasEnded {
                self.callCount += 1
                if let start = self.callStartDate {
                    self.callDurationMinutes += Date.now.timeIntervalSince(start) / 60
                    self.callStartDate = nil
                }
            }
        }
    }
}

struct MemoryOnlyDataSource: ActivityDataSource {
    let type: ActivityType
    private let tracker: MemoryOnlyActivityTracker

    fileprivate init(type: ActivityType, tracker: MemoryOnlyActivityTracker) {
        self.type = type
        self.tracker = tracker
    }

    func requestAuthorization() async throws {}

    func fetchTodayTotal() async throws -> Double {
        await MainActor.run {
            tracker.flush()
            switch type {
            case .callCount:            return tracker.callCount
            case .callDuration:         return tracker.callDurationMinutes
            case .earphoneUsageTime:    return tracker.earphoneMinutes
            case .chargingTime:         return tracker.chargingMinutes
            case .orientationChangeCount: return tracker.orientationChanges
            default:                    return 0
            }
        }
    }
}
