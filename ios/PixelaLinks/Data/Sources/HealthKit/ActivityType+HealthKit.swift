import HealthKit

extension ActivityType {
    var healthKitSampleType: HKSampleType? {
        switch self {
        case .stepCount:                  return HKQuantityType(.stepCount)
        case .walkingRunningDistance:     return HKQuantityType(.distanceWalkingRunning)
        case .flightsClimbed:             return HKQuantityType(.flightsClimbed)
        case .activeEnergyBurned:         return HKQuantityType(.activeEnergyBurned)
        case .basalEnergyBurned:          return HKQuantityType(.basalEnergyBurned)
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
        case .physicalEffort:             return HKQuantityType(.physicalEffort)
        case .heartRate:                  return HKQuantityType(.heartRate)
        case .oxygenSaturation:           return HKQuantityType(.oxygenSaturation)
        case .heartRateVariabilitySDNN:   return HKQuantityType(.heartRateVariabilitySDNN)
        case .walkingHeartRateAverage:    return HKQuantityType(.walkingHeartRateAverage)
        case .restingHeartRate:           return HKQuantityType(.restingHeartRate)
        case .walkingSpeed:               return HKQuantityType(.walkingSpeed)
        case .walkingDoubleSupportPercentage: return HKQuantityType(.walkingDoubleSupportPercentage)
        case .walkingStepLength:          return HKQuantityType(.walkingStepLength)
        case .walkingAsymmetryPercentage: return HKQuantityType(.walkingAsymmetryPercentage)
        default:                          return nil
        }
    }

    static var healthKitReadTypes: Set<HKObjectType> {
        Set(healthKitTypes.compactMap(\.healthKitSampleType))
    }
}
