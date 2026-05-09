# Phase 0-1：アーキテクチャ設計

## アーキテクチャパターン

**MVVM + Clean Architecture（3層構造）** を採用する。

### 選定理由

| 特性 | 影響 |
|------|------|
| UIはシンプル（設定画面中心） | 複雑なUI状態管理は不要 |
| バックグラウンド処理が複雑 | 副作用の制御・テスタビリティが重要 |
| 32種のデータソースが同じパターン | 抽象化・共通化が効く |
| 複数のバックグラウンド起動経路 | 調停ロジックの分離が必要 |

TCA（The Composable Architecture）も副作用管理に優れるが、UIの複雑さに対してオーバースペックのため不採用。

---

## レイヤー構造

```
ios/
├── Presentation/          # UI層
│   ├── Views/             # SwiftUI Views
│   └── ViewModels/        # 各画面のViewModel
│
├── Domain/                # ドメイン層（UIにもデータにも依存しない）
│   ├── Models/            # ActivityType, SyncConfig, SyncRecord 等
│   ├── Protocols/
│   │   ├── ActivityDataSource.swift   # 全データソースの共通プロトコル
│   │   └── PixelaRepository.swift
│   └── UseCases/
│       ├── SyncActivityUseCase.swift  # 差分計算→送信の中心ロジック
│       └── ConfigureActivityUseCase.swift
│
├── Data/                  # データ層
│   ├── Sources/           # 各データソースの実装（32種）
│   │   ├── HealthKit/
│   │   ├── Location/
│   │   ├── Photos/
│   │   ├── Connectivity/
│   │   ├── Communication/
│   │   ├── Calendar/
│   │   └── Device/
│   ├── Repositories/
│   │   ├── PixelaRepositoryImpl.swift
│   │   └── LocalStorageRepository.swift
│   └── Background/
│       ├── BackgroundSyncCoordinator.swift  # 複数の起動経路を調停
│       └── BackgroundTaskManager.swift
│
└── Infrastructure/
    ├── Network/           # URLSession wrapper
    └── Persistence/       # SwiftData models
```

---

## 中心となるプロトコル設計

全32種のデータソースをこの1つのプロトコルで抽象化する。

```swift
protocol ActivityDataSource {
    var type: ActivityType { get }
    func requestAuthorization() async throws
    func fetchTodayTotal() async throws -> Double
}
```

`ActivityType` は32種を列挙した enum。データソースの追加・削除がリストへの1行追加で完結する設計とする。

---

## バックグラウンド送信の中心設計

複数の起動経路（HealthKit / Location / BGAppRefresh 等）がすべてここに収束する。

```swift
class BackgroundSyncCoordinator {
    func sync(types: [ActivityType]) async {
        for type in types {
            guard let config = configStore.config(for: type),
                  config.isEnabled else { continue }
            do {
                let total  = try await dataSource(for: type).fetchTodayTotal()
                let stored = recordStore.lastSentRecord(for: type)
                let delta  = stored.requiresReset ? total
                                                  : total - stored.value
                guard delta > 0 else { continue }
                try await pixelaRepo.addPixel(delta: delta, config: config)
                recordStore.update(type: type, value: total)
            } catch {
                // 失敗はスキップ（次の送信タイミングで再試行）
            }
        }
    }
}
```

---

## 技術スタック

| 項目 | 選定 | 理由 |
|------|------|------|
| UI | SwiftUI | iOS 17以上なので制約なし |
| 永続化 | SwiftData | iOS 17以上・Swift nativeで相性が良い |
| 非同期処理 | async/await + AsyncStream | Combineより直感的 |
| 最小iOS | iOS 17 | `timeInDaylight` 等の全機能をカバーする最低ライン |
| 言語 | Swift 5.9以上 | |
