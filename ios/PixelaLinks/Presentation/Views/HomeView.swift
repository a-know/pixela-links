import SwiftUI
import SwiftData

struct HomeView: View {
    let account: PixelaAccountConfig
    let onAccountTap: () -> Void

    @Query private var configs: [ActivitySyncConfig]
    @Query private var errors: [ActivitySyncError]

    private var todayDateString: String {
        DateFormatter.pixelaDate.string(from: .now)
    }

    private var groupedTypes: [(ActivityCategory, [ActivityType])] {
        ActivityCategory.allCases.map { category in
            (category, ActivityType.allCases.filter { $0.category == category })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !account.isVerified {
                    unverifiedBanner
                }

                ForEach(groupedTypes, id: \.0) { category, types in
                    Section(category.rawValue) {
                        ForEach(types) { type in
                            if account.isVerified && type.isAvailableOnDevice {
                                NavigationLink {
                                    ActivityDetailView(activityType: type)
                                } label: {
                                    rowView(for: type)
                                }
                            } else {
                                rowView(for: type)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("PixelaLinks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onAccountTap) {
                        Label(account.username.isEmpty ? "設定" : account.username,
                              systemImage: "gearshape")
                            .foregroundStyle(account.isVerified ? Color.primary : Color.orange)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var unverifiedBanner: some View {
        Section {
            Button(action: onAccountTap) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("接続の確認が必要です")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("アカウント設定で「接続を確認する」を実行してください")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func rowView(for type: ActivityType) -> some View {
        let config = configs.first { $0.activityType == type.rawValue }
        let todayErrorCount = errors.filter {
            $0.activityType == type.rawValue && $0.dateString == todayDateString
        }.count
        return ActivityRowView(
            activityType: type,
            config: config,
            todayErrorCount: todayErrorCount
        )
    }
}
