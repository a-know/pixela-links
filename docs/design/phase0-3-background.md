# Phase 0-3：バックグラウンド処理設計

## 全体像

複数の起動経路がすべて1つのコーディネーターに収束する。

```
HealthKit Background Delivery  ─┐
Significant Location Change    ─┤
ジオフェンシング（出入り検知）    ─┤──→ BackgroundSyncCoordinator ──→ Pixela API
BGAppRefreshTask               ─┤         （Swift Actor）         （Background URLSession）
Bluetooth Central Background   ─┤
アプリ復帰時フラッシュ           ─┘
```

---

## BackgroundSyncCoordinator（Swift Actor）

Swift `actor` を使い、複数の起動経路からの同時呼び出しを安全に排他制御する。

```swift
actor BackgroundSyncCoordinator {
    private var activeSyncs: Set<ActivityType> = []

    func sync(types: [ActivityType]) async {
        // 既に処理中のものは重複実行しない
        let pending = types.filter { !activeSyncs.contains($0) }
        activeSyncs.formUnion(pending)
        defer { activeSyncs.subtract(pending) }

        await withTaskGroup(of: Void.self) { group in
            for type in pending {
                group.addTask { await self.syncOne(type) }
            }
        }
    }

    private func syncOne(_ type: ActivityType) async {
        guard let config = configStore.config(for: type),
              config.isEnabled else { return }
        do {
            let total  = try await dataSource(for: type).fetchTodayTotal()
            let record = recordStore.record(for: type)
            let delta  = record.requiresReset ? total : total - record.lastSentValue
            guard delta > 0 else { return }
            try await pixelaRepo.addPixel(delta: delta, config: config)
            recordStore.update(type: type, value: total)
        } catch {
            // 失敗はスキップ（次の送信タイミングで再試行）
        }
    }
}
```

---

## 各起動経路の設計

### 1. HealthKit Background Delivery

最も信頼性が高く、データ更新時にOSがアプリを起動する。`completionHandler` を必ず呼ぶことが必須（呼ばないとAppleがbackground deliveryを停止するペナルティを与える）。

```swift
func setupHealthKitBackgroundDelivery() {
    for type in ActivityType.healthKitTypes {
        guard let sampleType = type.healthKitSampleType else { continue }

        healthStore.enableBackgroundDelivery(
            for: sampleType, frequency: .immediate
        ) { _, _ in }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) {
            _, completionHandler, error in
            guard error == nil else { completionHandler(); return }
            Task {
                await coordinator.sync(types: [type])
                completionHandler() // 必須
            }
        }
        healthStore.execute(query)
    }
}
```

### 2. CoreLocation（Significant Location Change + ジオフェンシング）

```swift
func setupLocationBackgroundMonitoring(homeCoordinate: CLLocationCoordinate2D) {
    // 訪問場所変化回数の計測
    locationManager.startMonitoringSignificantLocationChanges()

    // 外出時間の計測（自宅ジオフェンス）
    let homeRegion = CLCircularRegion(
        center: homeCoordinate,
        radius: 150,
        identifier: ActivityType.timeOutside.rawValue
    )
    homeRegion.notifyOnEntry = true
    homeRegion.notifyOnExit  = true
    locationManager.startMonitoring(for: homeRegion)
}

func locationManager(_ manager: CLLocationManager,
                     didEnterRegion region: CLRegion) {
    // 帰宅 → 外出終了時刻を記録
}
func locationManager(_ manager: CLLocationManager,
                     didExitRegion region: CLRegion) {
    // 外出 → 外出開始時刻を記録
}
func locationManager(_ manager: CLLocationManager,
                     didUpdateLocations locations: [CLLocation]) {
    Task { await coordinator.sync(types: [.significantLocationChangeCount,
                                          .cumulativeElevationGain,
                                          .automotiveDistance,
                                          .automotiveTime]) }
}
```

### 3. BGTaskScheduler（定期バックグラウンド更新）

写真・標高・Wi-Fi・カレンダー・リマインダー・充電時間に使用。Info.plist への `BGTaskSchedulerPermittedIdentifiers` 登録が必要。

```swift
// アプリ起動時に登録
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.pixela.links.refresh",
    using: nil
) { task in
    Task {
        await coordinator.sync(types: ActivityType.bgRefreshTypes)
        task.setTaskCompleted(success: true)
    }
    task.expirationHandler = { task.setTaskCompleted(success: false) }
}

// 次回スケジュールを登録（実行のたびに再スケジュール）
func scheduleNextAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.pixela.links.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
}
```

### 4. Bluetooth Central Background Mode

`bluetooth-central` background mode を宣言することで、スキャン・接続イベントがバックグラウンドでも配信される。State Restoration（アプリ再起動後の状態復元）を有効化する。

```swift
let options = [CBCentralManagerOptionRestoreIdentifierKey: "pixela-links-central"]
centralManager = CBCentralManager(delegate: self, queue: nil, options: options)

func centralManager(_ central: CBCentralManager,
                    didConnect peripheral: CBPeripheral) {
    Task { await coordinator.sync(types: [.bluetoothConnectionCount]) }
}
```

### 5. 「メモリ上にいる間のみ」系のフラッシュ設計

通話・イヤホン・充電・向き変化は、アプリがバックグラウンドに移行するタイミングで累積データをフラッシュする。

```swift
// SceneDelegate
func sceneDidEnterBackground(_ scene: UIScene) {
    var bgTaskID = UIBackgroundTaskIdentifier.invalid
    bgTaskID = UIApplication.shared.beginBackgroundTask {
        UIApplication.shared.endBackgroundTask(bgTaskID)
    }
    Task {
        await coordinator.sync(types: ActivityType.memoryOnlyTypes)
        UIApplication.shared.endBackgroundTask(bgTaskID)
    }
}
```

---

## Background URLSession（HTTP送信の保証）

全てのPixela APIリクエストはBackground URLSessionを経由する。アプリが途中でkillされてもOSが送信を完遂する。

```swift
let config = URLSessionConfiguration.background(
    withIdentifier: "com.pixela.links.upload"
)
config.isDiscretionary = false
config.sessionSendsLaunchEvents = true
let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
```

---

## ActivityType のグループ分類（バックグラウンド起動経路別）

```swift
extension ActivityType {
    static var healthKitTypes: [ActivityType]  { /* #1〜#15 */ }
    static var locationTypes: [ActivityType]   { /* #19〜#23 */ }
    static var bgRefreshTypes: [ActivityType]  { /* #20・#28〜#30 */ }
    static var bluetoothTypes: [ActivityType]  { /* #27 */ }
    static var memoryOnlyTypes: [ActivityType] { /* #24〜#26・#31・#32 */ }
}
```

---

## Info.plist に必要な設定

```xml
<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>healthkit</string>
    <string>location</string>
    <string>bluetooth-central</string>
    <string>processing</string>
</array>

<!-- BGTaskScheduler -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.pixela.links.refresh</string>
</array>
```
