# Phase 0-2：データモデル設計

## 前提

- アプリ全体の Deployment Target は **iOS 17**
- 特定ハードウェアが必要な機能（Apple Watch系、iPhone 15以降限定等）は実行時の可用性チェックで対応
- Pixelaアカウント（username / token）はアプリ全体で1つ。データ種別ごとに設定するのはグラフIDのみ

---

## モデル一覧

### 1. `ActivityType`（データ種別の列挙）

```swift
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
}
```

各 `ActivityType` が持つプロパティ：

```swift
extension ActivityType {
    var displayName: String { ... }      // 表示名（日本語）
    var unit: String { ... }             // 単位（歩、分、m 等）
    var category: ActivityCategory { ... } // グループ分類

    var backgroundReliability: BackgroundReliability { ... }
    // .high  : HealthKit Background Delivery・ジオフェンシング等
    // .medium: BGAppRefresh
    // .low   : アプリがメモリ上にいる間のみ

    // 実行時のハードウェア可用性チェック（OSバージョンではなくデバイス機能で判定）
    var isAvailableOnDevice: Bool {
        switch self {
        case .daylightTime:
            return HKQuantityType.quantityType(forIdentifier: .timeInDaylight) != nil
        case .standTime, .handwashingCount, .fallCount,
             .cyclingDistance, .swimmingDistance:
            // Apple Watch のデータが HealthKit に存在するかで判定
            return checkAppleWatchDataAvailability()
        default:
            return true
        }
    }
}
```

---

### 2. `PixelaAccountConfig`（アカウント設定・アプリ全体で1つ）

```swift
struct PixelaAccountConfig {
    var username: String
    // token は Keychain に保存（SwiftDataには含めない）
}
```

> **APIトークンの保存先**：SwiftDataのストアファイルはiTunesバックアップに含まれる可能性があるため、APIトークンは **Keychain** に保存する。usernameは機密性が低いため UserDefaults または SwiftData に保存可。

---

### 3. `ActivitySyncConfig`（データ種別ごとの設定）

```swift
@Model
class ActivitySyncConfig {
    var activityType: String      // ActivityType.rawValue
    var isEnabled: Bool
    var pixelaGraphID: String     // グラフIDのみ（username/tokenはアカウント設定から取得）
    var createdAt: Date
    var updatedAt: Date
}
```

---

### 4. `ActivitySyncRecord`（最終送信状態）

差分計算のために「前回何を送ったか」を保持する。

```swift
@Model
class ActivitySyncRecord {
    var activityType: String      // ActivityType.rawValue
    var lastSentDate: Date        // 最終送信日
    var lastSentValue: Double     // 最終送信時の累計値
    var lastSyncedAt: Date        // 最終送信試行日時

    // 日付が変わっていたらリセットが必要
    var requiresReset: Bool {
        !Calendar.current.isDateInToday(lastSentDate)
    }
}
```

SwiftData は SQLite ベースのディスク永続化のため、アプリ再起動・端末再起動後もデータは保持される。アンインストール時のみ削除される。

---

## モデル間の関係

```
ActivityType（enum・32種）
    ↓ 1対1
ActivitySyncConfig（SwiftData）  ←→  PixelaAccountConfig（username: UserDefaults / token: Keychain）
    ↓ 1対1
ActivitySyncRecord（SwiftData）
```

---

## 永続化レイヤーの使い分け

| データ | 保存先 | 理由 |
|-------|-------|------|
| APIトークン | Keychain | 機密情報。バックアップ除外 |
| Pixelaユーザー名 | UserDefaults | 機密性低。軽量アクセスで十分 |
| グラフID・有効フラグ等 | SwiftData | 構造化データ。関係クエリが発生しうる |
| 最終送信値・日時 | SwiftData | 同上 |
