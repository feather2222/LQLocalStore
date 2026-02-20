//  Created by xiangduojia on 2026/2/17.

import Foundation

public struct CacheMonitorSnapshot: Encodable {
    public let totalCacheSize: UInt64
    public let maxCacheSize: UInt64
    public let hitCount: UInt
    public let missCount: UInt
    public let hitRate: Double
    public let tagStats: [String: UInt64]
    public let topLFU: [String]
    public let topLRU: [String]
    public let time: Date
}

extension LQLocalStore {
    /// 获取当前缓存监控快照
    public func getMonitorSnapshot(topN: Int = 10) -> CacheMonitorSnapshot {
        let tags = tagQuota.keys
        var tagStats: [String: UInt64] = [:]
        for tag in tags {
            tagStats[tag] = tagCacheSize(tag)
        }
        return CacheMonitorSnapshot(
            totalCacheSize: currentCacheSize(),
            maxCacheSize: maxCacheSize,
            hitCount: cacheHitCount(),
            missCount: cacheMissCount(),
            hitRate: cacheHitRate(),
            tagStats: tagStats,
            topLFU: topFilesByLFU(limit: topN),
            topLRU: topFilesByLRU(limit: topN),
            time: Date()
        )
    }
    /// 导出为可视化数据（JSON）
    public func exportMonitorSnapshotJSON(topN: Int = 10) -> String? {
        let snap = getMonitorSnapshot(topN: topN)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(snap)).flatMap { String(data: $0, encoding: .utf8) }
    }
}
