import HealthKit
import Foundation
import UIKit

final class HealthKitBackgroundManager {
    static let shared = HealthKitBackgroundManager()

    private let healthStore = HKHealthStore()
    // HKSampleType identifier → ActivityTypes that map to it
    private var observerMapping: [String: [ActivityType]] = [:]

    func start() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        buildMapping()
        Task { await requestAndObserve() }
    }

    private func buildMapping() {
        for activityType in ActivityType.healthKitTypes {
            guard let hkType = activityType.healthKitSampleType else { continue }
            observerMapping[hkType.identifier, default: []].append(activityType)
        }
    }

    private func requestAndObserve() async {
        let readTypes = ActivityType.healthKitReadTypes
        guard !readTypes.isEmpty else { return }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            return
        }

        var registered = Set<String>()
        for activityType in ActivityType.healthKitTypes {
            guard let sampleType = activityType.healthKitSampleType else { continue }
            guard registered.insert(sampleType.identifier).inserted else { continue }
            registerObserver(for: sampleType)
        }
    }

    private func registerObserver(for sampleType: HKSampleType) {
        let identifier = sampleType.identifier

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completion, error in
            guard error == nil, let self else { completion(); return }
            let types = self.observerMapping[identifier] ?? []
            Task { @MainActor in
                guard UIApplication.shared.isProtectedDataAvailable else {
                    completion()
                    return
                }
                await BackgroundSyncCoordinator.shared.sync(types: types)
                completion()
            }
        }

        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { _, _ in }
    }
}
