//  Created by xiangduojia on 2026/2/17.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension LQLocalStore {
    /// 注册系统事件监听（App 进入后台/前台自动清理）
    public func registerSystemEventHandlers() {
#if canImport(UIKit)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
#endif
    }
    /// 反注册
    public func unregisterSystemEventHandlers() {
#if canImport(UIKit)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
#endif
    }
#if canImport(UIKit)
    @objc private func appDidEnterBackground() {
        cleanExpiredCache()
        cleanIfOverLimit()
        // 可扩展：发送本地推送等
    }
    @objc private func appWillEnterForeground() {
        // 可扩展：预热缓存、统计上报等
    }
#endif
}
