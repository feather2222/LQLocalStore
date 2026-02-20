//  Created by xiangduojia on 2026/2/17.

import Foundation

public protocol CacheExpirePolicy {
    /// 返回某缓存项的过期时间（可按标签/优先级/业务自定义）
    func expireDate(for fileName: String, meta: CacheMeta) -> Date?
}

/// 默认过期策略：优先使用 meta.expireAt
public class DefaultExpirePolicy: CacheExpirePolicy {
    public init() {}
    public func expireDate(for fileName: String, meta: CacheMeta) -> Date? {
        return meta.expireAt
    }
}

extension LQLocalStore {
    /// 可插拔过期策略
    public var expirePolicy: CacheExpirePolicy {
        get { _expirePolicyQueue.sync { _expirePolicy } }
        set { _expirePolicyQueue.async(flags: .barrier) { self._expirePolicy = newValue } }
    }
    private static var _expirePolicy: CacheExpirePolicy = DefaultExpirePolicy()
    private static let _expirePolicyQueue = DispatchQueue(label: "lqLocalStore.expirePolicy.queue", attributes: .concurrent)
    private var _expirePolicy: CacheExpirePolicy {
        get { Self._expirePolicyQueue.sync { Self._expirePolicy } }
        set { Self._expirePolicyQueue.async(flags: .barrier) { Self._expirePolicy = newValue } }
    }
    private var _expirePolicyQueue: DispatchQueue { Self._expirePolicyQueue }
    /// 获取缓存项过期时间（支持自定义策略）
    public func getExpireDate(for fileName: String) -> Date? {
        guard let meta = loadMeta(for: fileName) else { return nil }
        return expirePolicy.expireDate(for: fileName, meta: meta)
    }
    /// 检查并清理所有自定义过期的缓存
    public func cleanCustomExpiredCache() {
        let files = (try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path)) ?? []
        for file in files where !file.hasSuffix(metaSuffix) {
            guard let meta = loadMeta(for: file) else { continue }
            if let expireAt = expirePolicy.expireDate(for: file, meta: meta), expireAt < Date() {
                removeCache(for: file)
                notifyExpire(fileName: file)
            }
        }
    }
}
