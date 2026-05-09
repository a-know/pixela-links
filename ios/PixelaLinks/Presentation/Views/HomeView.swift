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
                ForEach(groupedTypes, id: \.0) { category, types in
                    Section(category.rawValue) {
                        ForEach(types) { type in
                            Group {
                                if type.isAvailableOnDevice {
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
            }
            .navigationTitle("PixelaLinks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onAccountTap) {
                        Label(account.username, systemImage: "gearshape")
                    }
                }
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
