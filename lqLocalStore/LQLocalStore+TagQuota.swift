//  Created by xiangduojia on 2026/2/17.

import Foundation

extension LQLocalStore {
    /// 标签容量上限配置
    public var tagQuota: [String: UInt64] {
        get { _tagQuotaQueue.sync { _tagQuota } }
        set { _tagQuotaQueue.async(flags: .barrier) { self._tagQuota = newValue } }
    }
    private static var _tagQuota: [String: UInt64] = [:]
    private static let _tagQuotaQueue = DispatchQueue(label: "lqLocalStore.tagQuota.queue", attributes: .concurrent)
    private var _tagQuota: [String: UInt64] {
        get { Self._tagQuotaQueue.sync { Self._tagQuota } }
        set { Self._tagQuotaQueue.async(flags: .barrier) { Self._tagQuota = newValue } }
    }
    private var _tagQuotaQueue: DispatchQueue { Self._tagQuotaQueue }
    /// 设置单个标签容量上限
    public func setQuota(_ quota: UInt64, forTag tag: String) {
        tagQuota[tag] = quota
    }
    /// 获取标签已用空间
    public func tagCacheSize(_ tag: String) -> UInt64 {
        let files = getFileNames(withTag: tag)
        var total: UInt64 = 0
        for file in files {
            let url = cacheDirectory.appendingPathComponent(file)
            total += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { UInt64($0) } ?? 0
        }
        return total
    }
    /// 检查并清理超出标签容量的缓存（按优先级+LRU）
    public func cleanIfTagOverLimit(_ tag: String) {
        guard let quota = tagQuota[tag], quota > 0 else { return }
        let files = getFileNames(withTag: tag)
        var fileMetas: [(String, CacheMeta)] = []
        for file in files {
            if let meta = loadMeta(for: file) {
                fileMetas.append((file, meta))
            }
        }
        let total = tagCacheSize(tag)
        guard total > quota else { return }
        let evictList = evictionPolicy.filesToEvict(fileMetas: fileMetas, totalSize: total, maxSize: quota)
        var freed: UInt64 = 0
        for file in evictList {
            let url = cacheDirectory.appendingPathComponent(file)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { UInt64($0) } ?? 0
            try? fileManager.removeItem(at: url)
            let metaURL = cacheDirectory.appendingPathComponent(file + metaSuffix)
            try? fileManager.removeItem(at: metaURL)
            freed += size
            if total - freed <= quota { break }
        }
    }
}
