import SwiftUI

struct ActivityRowView: View {
    let activityType: ActivityType
    let config: ActivitySyncConfig?
    let todayErrorCount: Int

    private var isEnabled: Bool { config?.isEnabled == true }
    private var isConfigured: Bool { config != nil }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isEnabled ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(activityType.displayName)
                    .font(.body)

                if let note = activityType.hardwareNote {
                    Label(note, systemImage: "applewatch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if activityType.backgroundReliability == .low,
                          let warning = BackgroundReliability.low.warningMessage {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !isConfigured {
                    Text("未設定")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if todayErrorCount > 0 {
                Text("今日 \(todayErrorCount)エラー")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}
