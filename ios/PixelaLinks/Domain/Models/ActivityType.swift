import Foundation

enum ActivityType: String, CaseIterable, Identifiable {
    // HealthKit
    case stepCount
    case walkingDistance
    case runningDistance
    case flightsClimbed
    case activeEnergyBurned
    case exerciseTime
    case sleepDuration
    case standTime
    case daylightTime
    case handwashingCount
    case fallCount
    case cyclingDistance
    case swimmingDistance
    case loudEnvironmentCount
    case headphoneLoudExposureCount
    // 写真・メディア
    case photoLibraryAddCount
    case screenshotCount
    case videoRecordingDuration
    // 位置・移動
    case significantLocationChangeCount
    case cumulativeElevationGain
    case automotiveDistance
    case automotiveTime
    case timeOutside
    // 通話・音声
    case callCount
    case callDuration
    case earphoneUsageTime
    // 接続
    case bluetoothConnectionCount
    case wifiNetworkChangeCount
    // 予定・タスク
    case calendarEventCount
    case completedReminderCount
    // デバイス状態
    case chargingTime
    case orientationChangeCount

    var id: String { rawValue }
}

// MARK: - Display

extension ActivityType {
    var displayName: String {
        switch self {
        case .stepCount:                     return "歩数"
        case .walkingDistance:               return "歩行距離（m）"
        case .runningDistance:               return "走行距離（m）"
        case .flightsClimbed:                return "上った階数（階）"
        case .activeEnergyBurned:            return "アクティブ消費カロリー（kcal）"
        case .exerciseTime:                  return "運動時間（分）"
        case .sleepDuration:                 return "睡眠時間（分）"
        case .standTime:                     return "スタンド時間"
        case .daylightTime:                  return "日光浴時間（分）"
        case .handwashingCount:              return "手洗い回数"
        case .fallCount:                     return "転倒検知回数"
        case .cyclingDistance:               return "自転車走行距離"
        case .swimmingDistance:              return "水泳距離"
        case .loudEnvironmentCount:          return "大音量環境曝露回数"
        case .headphoneLoudExposureCount:    return "ヘッドフォン大音量曝露回数"
        case .photoLibraryAddCount:          return "カメラロール追加枚数"
        case .screenshotCount:               return "スクリーンショット撮影回数"
        case .videoRecordingDuration:        return "動画撮影時間"
        case .significantLocationChangeCount: return "訪問場所の変化回数"
        case .cumulativeElevationGain:       return "累積獲得標高（m）"
        case .automotiveDistance:            return "車での移動距離（km）"
        case .automotiveTime:                return "車での移動時間（分）"
        case .timeOutside:                   return "外出時間（分）"
        case .callCount:                     return "通話回数"
        case .callDuration:                  return "通話時間"
        case .earphoneUsageTime:             return "イヤホン使用時間"
        case .bluetoothConnectionCount:      return "Bluetooth接続回数"
        case .wifiNetworkChangeCount:        return "Wi-Fiネットワーク切り替え回数"
        case .calendarEventCount:            return "カレンダー予定数"
        case .completedReminderCount:        return "完了リマインダー数"
        case .chargingTime:                  return "充電時間"
        case .orientationChangeCount:        return "画面の向き変化回数"
        }
    }

    var unit: String {
        switch self {
        case .flightsClimbed:
            return "階"
        case .stepCount, .handwashingCount, .fallCount,
             .loudEnvironmentCount, .headphoneLoudExposureCount,
             .photoLibraryAddCount, .screenshotCount,
             .significantLocationChangeCount, .callCount,
             .bluetoothConnectionCount, .wifiNetworkChangeCount,
             .calendarEventCount, .completedReminderCount,
             .orientationChangeCount:
            return "回"
        case .walkingDistance, .runningDistance:
            return "m"
        case .cyclingDistance, .swimmingDistance, .automotiveDistance:
            return "km"
        case .activeEnergyBurned:
            return "kcal"
        case .exerciseTime, .sleepDuration, .standTime, .daylightTime,
             .automotiveTime, .timeOutside, .callDuration,
             .earphoneUsageTime, .chargingTime:
            return "分"
        case .videoRecordingDuration:
            return "秒"
        case .cumulativeElevationGain:
            return "m"
        }
    }
}

// MARK: - Category

enum ActivityCategory: String, CaseIterable {
    case healthKit      = "HealthKit"
    case photoMedia     = "写真・メディア"
    case locationMotion = "位置・移動"
    case callAudio      = "通話・音声"
    case connectivity   = "接続"
    case calendarTask   = "予定・タスク"
    case deviceState    = "デバイス状態"
}

extension ActivityType {
    var category: ActivityCategory {
        switch self {
        case .stepCount, .walkingDistance, .runningDistance, .flightsClimbed,
             .activeEnergyBurned, .exerciseTime, .sleepDuration, .standTime,
             .daylightTime, .handwashingCount, .fallCount, .cyclingDistance,
             .swimmingDistance, .loudEnvironmentCount, .headphoneLoudExposureCount:
            return .healthKit
        case .photoLibraryAddCount, .screenshotCount, .videoRecordingDuration:
            return .photoMedia
        case .significantLocationChangeCount, .cumulativeElevationGain,
             .automotiveDistance, .automotiveTime, .timeOutside:
            return .locationMotion
        case .callCount, .callDuration, .earphoneUsageTime:
            return .callAudio
        case .bluetoothConnectionCount, .wifiNetworkChangeCount:
            return .connectivity
        case .calendarEventCount, .completedReminderCount:
            return .calendarTask
        case .chargingTime, .orientationChangeCount:
            return .deviceState
        }
    }
}

// MARK: - Background Reliability

enum BackgroundReliability {
    case high
    case medium
    case low

    var warningMessage: String? {
        switch self {
        case .high, .medium: return nil
        case .low: return "⚠ アプリがバックグラウンドで終了すると精度が下がる場合があります"
        }
    }
}

extension ActivityType {
    var backgroundReliability: BackgroundReliability {
        switch self {
        case .stepCount, .walkingDistance, .runningDistance, .flightsClimbed,
             .activeEnergyBurned, .exerciseTime, .sleepDuration, .standTime,
             .daylightTime, .handwashingCount, .fallCount, .cyclingDistance,
             .swimmingDistance, .loudEnvironmentCount, .headphoneLoudExposureCount,
             .significantLocationChangeCount, .timeOutside, .bluetoothConnectionCount:
            return .high
        case .photoLibraryAddCount, .screenshotCount, .videoRecordingDuration,
             .cumulativeElevationGain, .automotiveDistance, .automotiveTime,
             .wifiNetworkChangeCount, .calendarEventCount, .completedReminderCount:
            return .medium
        case .callCount, .callDuration, .earphoneUsageTime,
             .chargingTime, .orientationChangeCount:
            return .low
        }
    }
}

// MARK: - Value Type

extension ActivityType {
    var isIntegerValue: Bool {
        switch self {
        case .stepCount, .flightsClimbed, .handwashingCount, .fallCount,
             .loudEnvironmentCount, .headphoneLoudExposureCount,
             .photoLibraryAddCount, .screenshotCount,
             .significantLocationChangeCount, .callCount,
             .bluetoothConnectionCount, .wifiNetworkChangeCount,
             .calendarEventCount, .completedReminderCount,
             .orientationChangeCount:
            return true
        default:
            return false
        }
    }
}

// MARK: - Hardware Requirements

extension ActivityType {
    var requiresAppleWatch: Bool {
        switch self {
        case .standTime, .handwashingCount, .fallCount,
             .cyclingDistance, .swimmingDistance:
            return true
        default:
            return false
        }
    }

    var hardwareNote: String? {
        switch self {
        case .daylightTime:
            return "iPhone 15 以降または Apple Watch Series 9/Ultra 2 が必要"
        default:
            return requiresAppleWatch ? "Apple Watch が必要" : nil
        }
    }

    // Phase 4 で各データソース実装時に精緻化する
    var isAvailableOnDevice: Bool { true }
}

// MARK: - Grouping by Background Mechanism

extension ActivityType {
    static var healthKitTypes: [ActivityType] {
        allCases.filter { $0.category == .healthKit }
    }

    static var bgRefreshTypes: [ActivityType] {
        [.photoLibraryAddCount, .screenshotCount, .videoRecordingDuration,
         .cumulativeElevationGain, .automotiveDistance, .automotiveTime,
         .wifiNetworkChangeCount, .calendarEventCount, .completedReminderCount]
    }

    static var bluetoothTypes: [ActivityType] {
        [.bluetoothConnectionCount]
    }

    static var memoryOnlyTypes: [ActivityType] {
        [.callCount, .callDuration, .earphoneUsageTime,
         .chargingTime, .orientationChangeCount]
    }
}
