# Phase 0-4：Pixela API連携設計

## 使用するAPIエンドポイント

### ピクセル加算

```
PUT /v1/users/{username}/graphs/{graphID}/{yyyyMMdd}/add
```

**リクエストヘッダー**
```
X-USER-TOKEN: {token}
Content-Type: application/json
```

**リクエストボディ**
```json
{ "quantity": "500" }
```

当日のピクセルが存在しない場合は自動作成、存在する場合は加算される。

### 接続確認（設定画面用）

隠しAPIのため公式ドキュメントには記載なし。ソースコードより確認済み。

```
POST /v1/users/{username}/authentication
```

**リクエストヘッダー**
```
X-USER-TOKEN: {token}
```

リクエストボディは不要。認証成功時は `{"message":"Success.","isSuccess":true}` を返す。

---

## エラーハンドリング方針

リトライは行わない。エラー発生時は `ActivitySyncError` に記録してスキップし、次の送信タイミングで自然に再試行される。

### ActivitySyncError モデル

当日のエラー件数を高速にクエリできるよう、`dateString`（`"yyyyMMdd"` 形式）を独立フィールドとして持つ。

```swift
@Model
class ActivitySyncError {
    var activityType: String    // ActivityType.rawValue
    var occurredAt: Date        // 発生日時（詳細表示用）
    var dateString: String      // "yyyyMMdd"（日別集計用: filter { $0.dateString == today } でカウント可能）
    var statusCode: Int?        // HTTPステータスコード（ネットワークエラーは nil）
    var message: String
}
```

日別エラー件数の導出例：

```swift
let todayErrors = errors.filter {
    $0.activityType == type.rawValue && $0.dateString == "20260430"
}
let count = todayErrors.count  // 今日のエラー回数
```

古いエラーレコードは BGAppRefreshTask のタイミングで定期パージする（目安：30日以上前）。

### エラー種別と対応方針

| HTTPステータス | 意味 | 対応 |
|:---:|------|------|
| 200 | 成功 | `ActivitySyncRecord` を更新 |
| 400 | リクエスト不正 | `ActivitySyncError` に記録してスキップ |
| 404 | グラフID不正 or 認証失敗 | 同上 |
| 503 | サーバー一時障害 | 同上（次回自然に再試行） |
| ネットワークエラー | 通信失敗 | 同上（statusCode は nil） |

---

## PixelaRepository の設計

```swift
protocol PixelaRepository {
    func addPixel(delta: Double, config: ActivitySyncConfig) async throws
    func validateAccount(username: String, token: String) async throws
}

struct PixelaRepositoryImpl: PixelaRepository {
    private let session: URLSession  // Background URLSession

    func addPixel(delta: Double, config: ActivitySyncConfig) async throws {
        let account = accountStore.load()
        let dateStr = DateFormatter.pixela.string(from: .now)  // "yyyyMMdd"
        var request = URLRequest(
            url: URL(string: "https://pixe.la/v1/users/\(account.username)"
                           + "/graphs/\(config.pixelaGraphID)/\(dateStr)/add")!
        )
        request.httpMethod = "PUT"
        request.setValue(account.token, forHTTPHeaderField: "X-USER-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            PixelPayload(quantity: formatQuantity(delta))
        )
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw PixelaError.requestFailed(
                (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }
    }

    func validateAccount(username: String, token: String) async throws {
        var request = URLRequest(
            url: URL(string: "https://pixe.la/v1/users/\(username)/authentication")!
        )
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "X-USER-TOKEN")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw PixelaError.authenticationFailed
        }
    }
}
```

---

## BackgroundSyncCoordinator のエラー記録込み処理

```swift
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
    } catch let error as PixelaError {
        errorStore.record(ActivitySyncError(
            activityType: type.rawValue,
            occurredAt: .now,
            dateString: DateFormatter.pixela.string(from: .now),
            statusCode: error.statusCode,
            message: error.localizedDescription
        ))
    } catch {
        errorStore.record(ActivitySyncError(
            activityType: type.rawValue,
            occurredAt: .now,
            dateString: DateFormatter.pixela.string(from: .now),
            statusCode: nil,
            message: error.localizedDescription
        ))
    }
}
```

---

## quantity のフォーマットルール

Pixelaは小数点第二位まで対応。整数の場合は小数点なしで送る。

```swift
func formatQuantity(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return String(Int(value))            // 500.0   → "500"
    } else {
        return String(format: "%.2f", value) // 1.2345  → "1.23"
    }
}
```
