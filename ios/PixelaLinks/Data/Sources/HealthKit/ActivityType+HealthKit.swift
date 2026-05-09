import HealthKit

extension ActivityType {
    var healthKitSampleType: HKSampleType? {
        switch self {
        case .stepCount:                  return HKQuantityType(.stepCount)
        case .walkingDistance:            return HKQuantityType(.distanceWalkingRunning)
        case .runningDistance:            return HKQuantityType(.distanceWalkingRunning)
        case .flightsClimbed:             return HKQuantityType(.flightsClimbed)
        case .activeEnergyBurned:         return HKQuantityType(.activeEnergyBurned)
        case .exerciseTime:               return HKQuantityType(.appleExerciseTime)
        case .sleepDuration:              return HKCategoryType(.sleepAnalysis)
        case .standTime:                  return HKQuantityType(.appleStandTime)
        case .daylightTime:               return HKQuantityType(.timeInDaylight)
        case .handwashingCount:           return HKCategoryType(.handwashingEvent)
        case .fallCount:                  return HKQuantityType(.numberOfTimesFallen)
        case .cyclingDistance:            return HKQuantityType(.distanceCycling)
        case .swimmingDistance:           return HKQuantityType(.distanceSwimming)
        case .loudEnvironmentCount:       return HKCategoryType(.environmentalAudioExposureEvent)
        case .headphoneLoudExposureCount: return HKCategoryType(.headphoneAudioExposureEvent)
        default:                          return nil
        }
    }

    static var healthKitReadTypes: Set<HKObjectType> {
        Set(healthKitTypes.compactMap(\.healthKitSampleType))
    }
}
