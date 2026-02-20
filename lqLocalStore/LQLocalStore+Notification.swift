//  Created by xiangduojia on 2026/2/17.

import Foundation
#if canImport(UIKit)
import UserNotifications
#endif

extension LQLocalStore {
    /// 发送本地推送（仅支持iOS/macOS）
    public func sendLocalNotification(title: String, body: String) {
#if canImport(UIKit)
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
#endif
    }
}
