import SwiftUI
import SwiftData

struct ActivityDetailView: View {
    let activityType: ActivityType

    @State private var viewModel: ActivityDetailViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [ActivitySyncRecord]
    @Query private var allErrors: [ActivitySyncError]
    @Query private var allHistory: [ActivitySendHistory]

    init(activityType: ActivityType) {
        self.activityType = activityType
        _viewModel = State(initialValue: ActivityDetailViewModel(activityType: activityType))
    }

    private var record: ActivitySyncRecord? {
        records.first { $0.activityType == activityType.rawValue }
    }

    private var sendHistory: [ActivitySendHistory] {
        allHistory
            .filter { $0.activityType == activityType.rawValue }
            .sorted { $0.sentAt > $1.sentAt }
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
                            Task { await viewModel.loadGraphs() }
                        }
                    }

                if viewModel.isEnabled {
                    graphPickerRow
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

            // 送信状況
            if let record {
                Section("送信状況") {
                    LabeledContent("本日の送信値") {
                        Text(record.requiresReset
                             ? "—"
                             : "\(formatValue(record.lastSentValue)) \(activityType.unit)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 送信履歴
            if !sendHistory.isEmpty {
                Section {
                    ForEach(sendHistory.prefix(10), id: \.sentAt) { entry in
                        SendHistoryRowView(entry: entry, unit: activityType.unit)
                    }
                    if sendHistory.count > 10 {
                        NavigationLink("すべて表示（\(sendHistory.count)件）") {
                            FullHistoryView(
                                title: "送信履歴",
                                history: sendHistory,
                                unit: activityType.unit
                            )
                        }
                    }
                } header: {
                    Text("送信履歴")
                }
            }

            // エラー履歴
            if !recentErrors.isEmpty {
                Section {
                    ForEach(recentErrors.prefix(10), id: \.occurredAt) { error in
                        ErrorRowView(error: error)
                    }
                    if recentErrors.count > 10 {
                        NavigationLink("すべて表示（\(recentErrors.count)件）") {
                            FullErrorView(
                                title: "エラー履歴",
                                errors: recentErrors
                            )
                        }
                    }
                } header: {
                    Text("エラー履歴")
                }
            }
        }
        .navigationTitle(activityType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = graphPageURL {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadIfNeeded(from: modelContext)
            if viewModel.isEnabled {
                Task { await viewModel.loadGraphs() }
            }
        }
    }

    // MARK: - Graph Page URL

    private var graphPageURL: URL? {
        guard !viewModel.selectedGraphID.isEmpty else { return nil }
        let account = PixelaAccountConfig.load()
        guard !account.username.isEmpty else { return nil }
        return URL(string: "https://pixe.la/v1/users/\(account.username)/graphs/\(viewModel.selectedGraphID).html")
    }

    // MARK: - Graph Picker

    @ViewBuilder
    private var graphPickerRow: some View {
        if viewModel.isLoadingGraphs {
            LabeledContent("グラフ") {
                ProgressView()
            }
        } else if !viewModel.graphs.isEmpty {
            Picker("グラフ", selection: $viewModel.selectedGraphID) {
                Text("（未選択）").tag("")
                ForEach(viewModel.graphs) { graph in
                    Text("\(graph.name)  [\(graph.id)]").tag(graph.id)
                }
            }
            .onChange(of: viewModel.selectedGraphID) { _, _ in
                viewModel.save(to: modelContext)
            }
        } else {
            LabeledContent("グラフ") {
                Button("グラフを取得") {
                    Task { await viewModel.loadGraphs() }
                }
            }
        }

        if let error = viewModel.graphsError {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.red)
        } else if !viewModel.isLoadingGraphs && viewModel.graphs.isEmpty {
            Label("グラフが見つかりません。Pixelaでグラフを作成してください。",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.2f", value)
    }
}

// MARK: - Full History Views

struct FullHistoryView: View {
    let title: String
    let history: [ActivitySendHistory]
    let unit: String

    var body: some View {
        List {
            ForEach(history, id: \.sentAt) { entry in
                SendHistoryRowView(entry: entry, unit: unit)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FullErrorView: View {
    let title: String
    let errors: [ActivitySyncError]

    var body: some View {
        List {
            ForEach(errors, id: \.occurredAt) { error in
                ErrorRowView(error: error)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Row Views

struct SendHistoryRowView: View {
    let entry: ActivitySendHistory
    let unit: String

    var body: some View {
        HStack {
            Text(DateFormatter.lastSent.string(from: entry.sentAt))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("+\(formatValue(entry.sentDelta)) \(unit)")
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
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
