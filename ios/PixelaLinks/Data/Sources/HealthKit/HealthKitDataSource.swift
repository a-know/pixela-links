import HealthKit
import Foundation

struct HealthKitDataSource: ActivityDataSource {
    let type: ActivityType

    func requestAuthorization() async throws {}

    func fetchTodayTotal() async throws -> Double {
        guard let today = Calendar.current.dateInterval(of: .day, for: .now) else { return 0 }

        switch type {
        case .stepCount:
            return try await querySum(.init(.stepCount), unit: .count(), day: today)

        case .walkingDistance, .runningDistance:
            return try await querySum(.init(.distanceWalkingRunning), unit: .meter(), day: today)

        case .flightsClimbed:
            return try await querySum(.init(.flightsClimbed), unit: .count(), day: today)

        case .activeEnergyBurned:
            return try await querySum(.init(.activeEnergyBurned), unit: .kilocalorie(), day: today)

        case .exerciseTime:
            return try await querySum(.init(.appleExerciseTime), unit: .minute(), day: today)

        case .sleepDuration:
            return try await querySleepMinutes(day: today)

        case .standTime:
            return try await querySum(.init(.appleStandTime), unit: .minute(), day: today)

        case .daylightTime:
            let s = try await querySum(.init(.timeInDaylight), unit: .second(), day: today)
            return s / 60

        case .handwashingCount:
            return try await queryCategoryCount(.init(.handwashingEvent), day: today)

        case .fallCount:
            return try await querySum(.init(.numberOfTimesFallen), unit: .count(), day: today)

        case .cyclingDistance:
            let m = try await querySum(.init(.distanceCycling), unit: .meter(), day: today)
            return m / 1000

        case .swimmingDistance:
            let m = try await querySum(.init(.distanceSwimming), unit: .meter(), day: today)
            return m / 1000

        case .loudEnvironmentCount:
            return try await queryCategoryCount(.init(.environmentalAudioExposureEvent), day: today)

        case .headphoneLoudExposureCount:
            return try await queryCategoryCount(.init(.headphoneAudioExposureEvent), day: today)

        default:
            return 0
        }
    }

    private func querySum(
        _ quantityType: HKQuantityType,
        unit: HKUnit,
        day: DateInterval
    ) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(
            withStart: day.start, end: day.end, options: .strictStartDate
        )
        let store = HKHealthStore()
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private func queryCategoryCount(
        _ categoryType: HKCategoryType,
        day: DateInterval
    ) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(
            withStart: day.start, end: day.end, options: .strictStartDate
        )
        let store = HKHealthStore()
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: Double(samples?.count ?? 0))
            }
            store.execute(query)
        }
    }

    private func querySleepMinutes(day: DateInterval) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(
            withStart: day.start, end: day.end, options: .strictStartDate
        )
        let store = HKHealthStore()
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let sleepStages: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                ]
                let minutes = (samples as? [HKCategorySample] ?? [])
                    .filter { sleepStages.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60 }
                continuation.resume(returning: minutes)
            }
            store.execute(query)
        }
    }
}
