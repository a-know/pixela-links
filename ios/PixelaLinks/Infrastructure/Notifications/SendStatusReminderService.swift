import Foundation
import UserNotifications

enum SendStatusReminderService {
    private static let enabledKey = "send_status_reminder_enabled"
    private static let notificationIDPrefix = "send-status-reminder-"
    private static let reminderHours = Array(stride(from: 6, through: 22, by: 2))

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool) async throws {
        if enabled {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .notDetermined:
                guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                    throw ReminderError.authorizationDenied
                }
            case .authorized, .provisional, .ephemeral:
                break
            case .denied:
                throw ReminderError.authorizationDenied
            @unknown default:
                throw ReminderError.authorizationDenied
            }

            do {
                try await scheduleReminders(with: center)
            } catch {
                removeReminders()
                throw error
            }
        } else {
            removeReminders()
        }

        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    static func restoreScheduleIfNeeded() async {
        guard isEnabled else { return }
        do {
            try await setEnabled(true)
        } catch {
            UserDefaults.standard.set(false, forKey: enabledKey)
            removeReminders()
        }
    }

    private static func scheduleReminders(with center: UNUserNotificationCenter) async throws {
        removeReminders()

        for hour in reminderHours {
            let content = UNMutableNotificationContent()
            content.title = "Pixela Links"
            content.body = "送信状況を確認しましょう。"
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: hour),
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }

    private static func removeReminders() {
        let identifiers = reminderHours.map(notificationIdentifier(for:))
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private static func notificationIdentifier(for hour: Int) -> String {
        "\(notificationIDPrefix)\(hour)"
    }
}

extension SendStatusReminderService {
    enum ReminderError: LocalizedError {
        case authorizationDenied

        var errorDescription: String? {
            "通知が許可されていません。iPhoneの設定からPixela Linksの通知を許可してください。"
        }
    }
}
