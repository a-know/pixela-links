# Pixela Links

## コンセプト

> 「iPhone をいつも通り利用するだけで、さまざまなアクティビティ情報を Pixela に自動連携する」

ユーザーが意識することなく、iPhone の各種センサー・フレームワークからデータを収集し、Pixela の Add Pixel API へ自動送信するiOSアプリ。

---

## 基本設計方針

### データ送信方式

- **差分送信**：前回送信時からの増分（delta）を計算して送信
- Pixela の add specific pixel API は加算（additive）動作のため、差分送信がそのまま機能する
- 日付をまたいだ場合はローカル保存値をリセット

### プライバシー設計

- ユーザーが各データ種別に対して明示的に送信先URLを設定した場合のみ送信
- 未設定のデータは一切外部送信しない

### 差分送信ロジック

```
ローカルに保存: { date: "2026-04-30", lastValue: 3000 }

HealthKit更新通知
  → 本日の累計値を取得: 3500歩
  → delta = 3500 - 3000 = 500
  → delta > 0 なら add specific pixel API に 500 を POST
  → lastValue を 3500 に更新

日付が変わった場合
  → lastValue を 0 にリセット
```

---

## 対象データ（全32種）

バックグラウンド信頼性：**高**=OS が起動してくれる / **中**=Background App Refresh 依存 / **低**=アプリがメモリ上にある間のみ取得可能

### HealthKit系（15種） — 信頼性：高

| # | データ種別 | 単位 | 備考 |
|---|-----------|------|------|
| 1 | 歩数 | 回 | |
| 2 | 歩行距離 | km | |
| 3 | 走行距離 | km | |
| 4 | 上った階数 | 回 | |
| 5 | アクティブ消費カロリー | kcal | |
| 6 | 運動時間 | 分 | |
| 7 | 睡眠時間 | 分 | 翌朝に送信する設計が自然 |
| 8 | スタンド時間 | 分 | Apple Watch必要 |
| 9 | 日光浴時間 | 分 | iPhone 15以降 または Apple Watch S9/Ultra 2 必要 |
| 10 | 手洗い回数 | 回 | Apple Watch必要 |
| 11 | 転倒検知回数 | 回 | Apple Watch必要 |
| 12 | 自転車走行距離 | km | Apple Watch必要 |
| 13 | 水泳距離 | km | Apple Watch必要（防水モデル） |
| 14 | 大音量環境曝露回数 | 回 | 80dB以上の騒音に3分以上さらされた回数 |
| 15 | ヘッドフォン大音量曝露回数 | 回 | イヤホン経由の危険音量曝露回数 |

### 写真・メディア系（3種） — 信頼性：中

| # | データ種別 | 単位 | 備考 |
|---|-----------|------|------|
| 16 | カメラロール追加枚数 | 回 | フルアクセス許可が必要 |
| 17 | スクリーンショット撮影回数 | 回 | `PHAssetMediaSubtype.photoScreenshot` でフィルタ |
| 18 | 動画撮影時間 | 秒 | 本日追加された動画アセットのduration合算 |

### 位置・移動系（5種）

| # | データ種別 | 単位 | 信頼性 | 備考 |
|---|-----------|------|--------|------|
| 19 | 訪問場所の変化回数 | 回 | 高 | Significant Location Change |
| 20 | 累積獲得標高 | m | 中 | CMAltimeter。屋内エレベーターも拾う |
| 21 | 車での移動距離 | km | 中 | CoreMotion（`.automotive`）+ CoreLocation |
| 22 | 車での移動時間 | 分 | 中 | CoreMotion activity分類 |
| 23 | 外出時間 | 分 | 高 | ジオフェンシング（自宅登録が必要） |

### 通話・音声系（3種） — 信頼性：低

| # | データ種別 | 単位 | 備考 |
|---|-----------|------|------|
| 24 | 通話回数 | 回 | CallKit `CXCallObserver` |
| 25 | 通話時間 | 分 | 同上 |
| 26 | イヤホン使用時間 | 分 | `AVAudioSession.routeChangeNotification` |

### 接続系（2種）

| # | データ種別 | 単位 | 信頼性 | 備考 |
|---|-----------|------|--------|------|
| 27 | Bluetooth接続回数 | 回 | 高 | `bluetooth-central` background mode |
| 28 | Wi-Fiネットワーク切り替え回数 | 回 | 中 | NWPathMonitor |

### 予定・タスク系（2種） — 信頼性：中

| # | データ種別 | 単位 | 備考 |
|---|-----------|------|------|
| 29 | カレンダー予定数 | 回 | EventKit。今日開始のイベント数を累積カウント |
| 30 | 完了リマインダー数 | 回 | EventKit |

### デバイス状態系（2種） — 信頼性：低

| # | データ種別 | 単位 | 備考 |
|---|-----------|------|------|
| 31 | 充電時間 | 分 | `UIDevice.batteryState` 変化を累積 |
| 32 | 画面の向き変化回数 | 回 | `UIDevice.orientationDidChangeNotification` |

---

## アーキテクチャ

### レイヤー構成

```
App/                  エントリーポイント・DI
Data/                 データソース実装・リポジトリ実装・バックグラウンド同期
  Sources/
    HealthKit/        HealthKit系データ取得
    Photos/           写真・メディア系
    Location/         位置・移動系
    Motion/           車移動系（CoreMotion）
    Bluetooth/        Bluetooth接続系
    Connectivity/     Wi-Fi切り替え系
    Calendar/         カレンダー・リマインダー系
    MemoryOnly/       通話・充電・画面向き系
  Background/         BackgroundSyncCoordinator
  Repositories/       PixelaRepositoryImpl・LocalStorageRepository
Domain/               モデル・プロトコル定義
Infrastructure/       ネットワーク・永続化基盤（NetworkClient・SwiftData・Keychain）
Presentation/         SwiftUI Views・ViewModels
```

### バックグラウンド動作の仕組み

```
HealthKit Background Delivery   → #1〜15
PHPhotoLibrary変化検知           → #16〜18（Background App Refresh併用）
Significant Location Change     → #19
Background App Refresh          → #20・#28〜#30
Location Always（常時）          → #21・#22
ジオフェンシング（常時）          → #23
Bluetooth Central Background    → #27
アプリがメモリ上にいる間のみ      → #24〜#26・#31・#32
```

### 必要なBackground Modes

```
- background-fetch
- healthkit
- location
- bluetooth-central
```

### 必要な権限

```
- HealthKit（読み取り）
- 写真ライブラリ（フルアクセス）
- 位置情報（常に許可）
- Bluetooth
- カレンダー
- リマインダー
```

### データフロー

```
各種フレームワークからの通知・更新
  ↓
差分計算（本日累計値 - ローカル保存値）
  ↓
delta > 0 の場合のみ
  ↓
URLSession で
PUT https://pixe.la/v1/users/{username}/graphs/{graphID}/{date}/add
  header: X-USER-TOKEN
  body: { "quantity": "<delta>" }
  ↓
ローカル状態を更新（SwiftData）
```

### 使用するAPI

| 用途 | メソッド | エンドポイント |
|---|---|---|
| ピクセル加算（データ送信） | PUT | `/v1/users/{username}/graphs/{graphID}/{date}/add` |
| アカウント認証確認 | POST | `/v1/users/{username}/authentication` |
| グラフ一覧取得 | GET | `/v1/users/{username}/graphs` |

### ローカル永続化

- **SwiftData**：各データ種別の最終送信日・最終送信値・エラーログ
- **Keychain**：APIトークンの安全な保存
- **URLSession**（フォアグラウンド）：現時点の送信セッション

---

## UX設計方針

### 設定画面のイメージ

```
[歩数]
  送信先URL: https://pixe.la/v1/users/xxx/graphs/steps/...
  ユーザー名: xxx  グラフID: steps
  APIトークン: ***
  ステータス: 有効 ✓

[歩行距離]
  （未設定）

[走行距離]
  （未設定）
  ...
```

- ユーザーが明示的に設定したデータ種別のみ送信
- 設定していない種別は収集も送信もしない

---

## 技術的な注意点

### 睡眠データの特殊性

睡眠データは他のデータと異なり、時間区間のリストとして記録される。

- `HKCategoryTypeIdentifier.sleepAnalysis` の区間を合算して分換算
- 「昨日の睡眠時間」として翌朝に送信する設計が自然

### 「アプリがメモリ上にいる必要あり」の意味

一部のデータ（#24〜#26・#31・#32）はHealthKitのような真のバックグラウンド起動ができない。アプリが完全にkillされると取りこぼしが発生する可能性がある。UIに「精度が下がる場合があります」等の注記を検討。

### 日光浴時間のハードウェア要件

`timeInDaylight`（#9）はiOS 17以降 かつ iPhone 15以降、またはApple Watch Series 9 / Ultra 2が必要。非対応端末ではこの項目をグレーアウトする。

### 外出時間の初回設定

`外出時間`（#23）はジオフェンシングで「自宅」を判定するため、初回設定時に自宅位置の登録が必要。

### iPhone と Apple Watch の併用時における HealthKit データの重複排除

`HKStatisticsQuery` に `.cumulativeSum` を指定した場合、HealthKit は複数ソース間の重複を自動的に排除する。歩数など累積型データでは、同じ時間帯に iPhone と Apple Watch の両方で記録がある場合、**Apple Watch のデータが優先**される。iPhone のみ・Apple Watch のみの場合はそのままそのデバイスのデータが使われる。アプリ側でソースを絞り込む処理は不要。
