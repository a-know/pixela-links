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

        case .walkingRunningDistance:
            return try await querySum(.init(.distanceWalkingRunning), unit: .meter(), day: today)

        case .flightsClimbed:
            return try await querySum(.init(.flightsClimbed), unit: .count(), day: today)

        case .activeEnergyBurned:
            return try await querySum(.init(.activeEnergyBurned), unit: .kilocalorie(), day: today)

        case .basalEnergyBurned:
            return try await querySum(.init(.basalEnergyBurned), unit: .kilocalorie(), day: today)

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
            return try await querySum(.init(.distanceCycling), unit: .meter(), day: today)

        case .swimmingDistance:
            let m = try await querySum(.init(.distanceSwimming), unit: .meter(), day: today)
            return m / 1000

        case .loudEnvironmentCount:
            return try await queryCategoryCount(.init(.environmentalAudioExposureEvent), day: today)

        case .headphoneLoudExposureCount:
            return try await queryCategoryCount(.init(.headphoneAudioExposureEvent), day: today)

        case .physicalEffort:
            return try await queryAverage(.init(.physicalEffort), unit: HKUnit(from: "kcal/(kg*hr)"), day: today)

        case .heartRate:
            return try await queryAverage(.init(.heartRate), unit: .count().unitDivided(by: .minute()), day: today)

        case .oxygenSaturation:
            let v = try await queryAverage(.init(.oxygenSaturation), unit: .percent(), day: today)
            return v * 100

        case .heartRateVariabilitySDNN:
            return try await queryAverage(.init(.heartRateVariabilitySDNN), unit: .secondUnit(with: .milli), day: today)

        case .walkingHeartRateAverage:
            return try await queryAverage(.init(.walkingHeartRateAverage), unit: .count().unitDivided(by: .minute()), day: today)

        case .restingHeartRate:
            return try await queryAverage(.init(.restingHeartRate), unit: .count().unitDivided(by: .minute()), day: today)

        case .walkingSpeed:
            return try await queryAverage(.init(.walkingSpeed), unit: .meter().unitDivided(by: .second()), day: today)

        case .walkingDoubleSupportPercentage:
            let v = try await queryAverage(.init(.walkingDoubleSupportPercentage), unit: .percent(), day: today)
            return v * 100

        case .walkingStepLength:
            return try await queryAverage(.init(.walkingStepLength), unit: .meterUnit(with: .centi), day: today)

        case .walkingAsymmetryPercentage:
            let v = try await queryAverage(.init(.walkingAsymmetryPercentage), unit: .percent(), day: today)
            return v * 100

        default:
            return 0
        }
    }

    func fetchDailyHistory(from startDate: Date, to endDate: Date) async throws -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: startDate)
        let to   = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!

        switch type {
        case .stepCount:
            return try await queryDailyCollection(.init(.stepCount), options: .cumulativeSum, unit: .count(), from: from, to: to)
        case .walkingRunningDistance:
            return try await queryDailyCollection(.init(.distanceWalkingRunning), options: .cumulativeSum, unit: .meter(), from: from, to: to)
        case .flightsClimbed:
            return try await queryDailyCollection(.init(.flightsClimbed), options: .cumulativeSum, unit: .count(), from: from, to: to)
        case .activeEnergyBurned:
            return try await queryDailyCollection(.init(.activeEnergyBurned), options: .cumulativeSum, unit: .kilocalorie(), from: from, to: to)
        case .basalEnergyBurned:
            return try await queryDailyCollection(.init(.basalEnergyBurned), options: .cumulativeSum, unit: .kilocalorie(), from: from, to: to)
        case .exerciseTime:
            return try await queryDailyCollection(.init(.appleExerciseTime), options: .cumulativeSum, unit: .minute(), from: from, to: to)
        case .sleepDuration:
            return try await queryDailySleepMinutes(from: from, to: to)
        case .standTime:
            return try await queryDailyCollection(.init(.appleStandTime), options: .cumulativeSum, unit: .minute(), from: from, to: to)
        case .daylightTime:
            return try await queryDailyCollection(.init(.timeInDaylight), options: .cumulativeSum, unit: .second(), from: from, to: to, transform: { $0 / 60 })
        case .handwashingCount:
            return try await queryDailyCategoryCount(.init(.handwashingEvent), from: from, to: to)
        case .fallCount:
            return try await queryDailyCollection(.init(.numberOfTimesFallen), options: .cumulativeSum, unit: .count(), from: from, to: to)
        case .cyclingDistance:
            return try await queryDailyCollection(.init(.distanceCycling), options: .cumulativeSum, unit: .meter(), from: from, to: to)
        case .swimmingDistance:
            return try await queryDailyCollection(.init(.distanceSwimming), options: .cumulativeSum, unit: .meter(), from: from, to: to, transform: { $0 / 1000 })
        case .loudEnvironmentCount:
            return try await queryDailyCategoryCount(.init(.environmentalAudioExposureEvent), from: from, to: to)
        case .headphoneLoudExposureCount:
            return try await queryDailyCategoryCount(.init(.headphoneAudioExposureEvent), from: from, to: to)
        case .physicalEffort:
            return try await queryDailyCollection(.init(.physicalEffort), options: .discreteAverage, unit: HKUnit(from: "kcal/(kg*hr)"), from: from, to: to)
        case .heartRate:
            return try await queryDailyCollection(.init(.heartRate), options: .discreteAverage, unit: .count().unitDivided(by: .minute()), from: from, to: to)
        case .oxygenSaturation:
            return try await queryDailyCollection(.init(.oxygenSaturation), options: .discreteAverage, unit: .percent(), from: from, to: to, transform: { $0 * 100 })
        case .heartRateVariabilitySDNN:
            return try await queryDailyCollection(.init(.heartRateVariabilitySDNN), options: .discreteAverage, unit: .secondUnit(with: .milli), from: from, to: to)
        case .walkingHeartRateAverage:
            return try await queryDailyCollection(.init(.walkingHeartRateAverage), options: .discreteAverage, unit: .count().unitDivided(by: .minute()), from: from, to: to)
        case .restingHeartRate:
            return try await queryDailyCollection(.init(.restingHeartRate), options: .discreteAverage, unit: .count().unitDivided(by: .minute()), from: from, to: to)
        case .walkingSpeed:
            return try await queryDailyCollection(.init(.walkingSpeed), options: .discreteAverage, unit: .meter().unitDivided(by: .second()), from: from, to: to)
        case .walkingDoubleSupportPercentage:
            return try await queryDailyCollection(.init(.walkingDoubleSupportPercentage), options: .discreteAverage, unit: .percent(), from: from, to: to, transform: { $0 * 100 })
        case .walkingStepLength:
            return try await queryDailyCollection(.init(.walkingStepLength), options: .discreteAverage, unit: .meterUnit(with: .centi), from: from, to: to)
        case .walkingAsymmetryPercentage:
            return try await queryDailyCollection(.init(.walkingAsymmetryPercentage), options: .discreteAverage, unit: .percent(), from: from, to: to, transform: { $0 * 100 })
        default:
            return []
        }
    }

    private func queryDailyCollection(
        _ quantityType: HKQuantityType,
        options: HKStatisticsOptions,
        unit: HKUnit,
        from: Date,
        to: Date,
        transform: ((Double) -> Double)? = nil
    ) async throws -> [(date: Date, value: Double)] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let store = HKHealthStore()
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: from,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, error in
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                var entries: [(date: Date, value: Double)] = []
                results?.enumerateStatistics(from: from, to: to) { stats, _ in
                    let raw: Double
                    if options.contains(.cumulativeSum) {
                        raw = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                    } else {
                        raw = stats.averageQuantity()?.doubleValue(for: unit) ?? 0
                    }
                    entries.append((date: stats.startDate, value: transform?(raw) ?? raw))
                }
                continuation.resume(returning: entries)
            }
            store.execute(query)
        }
    }

    private func queryDailyCategoryCount(
        _ categoryType: HKCategoryType,
        from: Date,
        to: Date
    ) async throws -> [(date: Date, value: Double)] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let store = HKHealthStore()
        let calendar = Calendar.current
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                var countByDay: [Date: Double] = [:]
                for sample in (samples ?? []) {
                    let day = calendar.startOfDay(for: sample.startDate)
                    countByDay[day, default: 0] += 1
                }
                continuation.resume(returning: countByDay.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 })
            }
            store.execute(query)
        }
    }

    private func queryDailySleepMinutes(from: Date, to: Date) async throws -> [(date: Date, value: Double)] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let store = HKHealthStore()
        let calendar = Calendar.current
        let sleepStages: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        ]
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                var minutesByDay: [Date: Double] = [:]
                for sample in (samples as? [HKCategorySample] ?? []) where sleepStages.contains(sample.value) {
                    let day = calendar.startOfDay(for: sample.startDate)
                    minutesByDay[day, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 60
                }
                continuation.resume(returning: minutesByDay.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 })
            }
            store.execute(query)
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
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: 0)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
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
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: 0)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                continuation.resume(returning: Double(samples?.count ?? 0))
            }
            store.execute(query)
        }
    }

    private func queryAverage(
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
                options: .discreteAverage
            ) { _, result, error in
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: 0)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                continuation.resume(returning: result?.averageQuantity()?.doubleValue(for: unit) ?? 0)
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
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: 0)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
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
