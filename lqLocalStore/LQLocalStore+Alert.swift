//  Created by xiangduojia on 2026/2/17.

import Foundation

public protocol CacheAlertHandler: AnyObject {
    func cacheUsageAlert(current: UInt64, max: UInt64)
}

extension LQLocalStore {
    /// 预警阈值（0~1），如0.8表示80%触发
    public var alertThreshold: Double {
        get { _alertThresholdQueue.sync { _alertThreshold } }
        set { _alertThresholdQueue.async(flags: .barrier) { self._alertThreshold = newValue } }
    }
    private static var _alertThreshold: Double = 0.8
    private static let _alertThresholdQueue = DispatchQueue(label: "lqLocalStore.alertThreshold.queue", attributes: .concurrent)
    private var _alertThreshold: Double {
        get { Self._alertThresholdQueue.sync { Self._alertThreshold } }
        set { Self._alertThresholdQueue.async(flags: .barrier) { Self._alertThreshold = newValue } }
    }
    private var _alertThresholdQueue: DispatchQueue { Self._alertThresholdQueue }
    /// 预警回调
    public weak var alertHandler: CacheAlertHandler? {
        get { _alertHandlerQueue.sync { _alertHandler } }
        set { _alertHandlerQueue.async(flags: .barrier) { self._alertHandler = newValue } }
    }
    private static weak var _alertHandler: CacheAlertHandler?
    private static let _alertHandlerQueue = DispatchQueue(label: "lqLocalStore.alertHandler.queue", attributes: .concurrent)
    private var _alertHandler: CacheAlertHandler? {
        get { Self._alertHandlerQueue.sync { Self._alertHandler } }
        set { Self._alertHandlerQueue.async(flags: .barrier) { Self._alertHandler = newValue } }
    }
    private var _alertHandlerQueue: DispatchQueue { Self._alertHandlerQueue }
    /// 检查并触发预警/自动扩容/清理
    public func checkAndAlertIfNeeded() {
        let usage = currentCacheSize()
        let max = maxCacheSize
        if max > 0 && Double(usage) / Double(max) >= alertThreshold {
            alertHandler?.cacheUsageAlert(current: usage, max: max)
            // 可扩展：自动扩容或清理
            autoExpandOrClean()
        }
    }
    /// 自动扩容或清理策略（可自定义）
    public func autoExpandOrClean() {
        // 默认策略：优先扩容（翻倍），如已达上限则清理
        if maxCacheSize < UInt64.max / 2 {
            maxCacheSize = maxCacheSize * 2
        } else {
            cleanIfOverLimit()
        }
    }
}
