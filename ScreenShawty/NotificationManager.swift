import UserNotifications

final class NotificationManager {

    static let shared = NotificationManager()

    private var authorized = false

    init() {
        requestPermission()
    }

    private func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            self.authorized = granted
        }
    }

    func show(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
}
