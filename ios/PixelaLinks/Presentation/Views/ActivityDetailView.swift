import SwiftUI
import SwiftData

struct ActivityDetailView: View {
    let activityType: ActivityType

    @State private var viewModel: ActivityDetailViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [ActivitySyncRecord]
    @Query private var allErrors: [ActivitySyncError]

    init(activityType: ActivityType) {
        self.activityType = activityType
        _viewModel = State(initialValue: ActivityDetailViewModel(activityType: activityType))
    }

    private var record: ActivitySyncRecord? {
        records.first { $0.activityType == activityType.rawValue }
    }

    private var recentErrors: [ActivitySyncError] {
        allErrors
            .filter { $0.activityType == activityType.rawValue }
            .sorted { $0.occurredAt > $1.occurredAt }
            .prefix(30)
            .map { $0 }
    }

    var body: some View {
        Form {
            // 送信設定
            Section {
                Toggle("Pixelaに送信", isOn: $viewModel.isEnabled)
                    .onChange(of: viewModel.isEnabled) { _, newValue in
                        viewModel.save(to: modelContext)
                        if newValue {
                            Task { await AppContainer.requestAuthorization(for: activityType) }
                        }
                    }
                if viewModel.isEnabled {
                    LabeledContent("グラフID") {
                        TextField("例: my-steps", text: $viewModel.graphID)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: viewModel.graphID) { _, _ in
                                viewModel.save(to: modelContext)
                            }
                    }
                }
            }

            // ハードウェア注記
            if let note = activityType.hardwareNote {
                Section {
                    Label(note, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // バックグラウンド精度注記
            if activityType.backgroundReliability == .low,
               let warning = BackgroundReliability.low.warningMessage {
                Section {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            // 同期状況
            if let record {
                Section("同期状況") {
                    LabeledContent("最終同期") {
                        Text(record.lastSyncedAt == .distantPast
                             ? "未同期"
                             : record.lastSyncedAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("本日の送信値") {
                        Text(record.requiresReset
                             ? "—"
                             : "\(formatValue(record.lastSentValue)) \(activityType.unit)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // エラー履歴
            if !recentErrors.isEmpty {
                Section("エラー履歴") {
                    ForEach(recentErrors, id: \.occurredAt) { error in
                        ErrorRowView(error: error)
                    }
                }
            }
        }
        .navigationTitle(activityType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadIfNeeded(from: modelContext)
        }
    }

    private func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.2f", value)
    }
}

struct ErrorRowView: View {
    let error: ActivitySyncError

    var body: some View {
        HStack(spacing: 8) {
            Text(error.occurredAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 100, alignment: .leading)

            if let code = error.statusCode {
                Text("\(code)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
            } else {
                Text("NW")
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange)
            }

            Text(error.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
