//  Created by xiangduojia on 2026/2/17.

import Foundation

extension LQLocalStore {
    /// 获取访问次数（LFU）
    public func getAccessCount(for fileName: String) -> Int {
        heatTracker.getAccessCount(for: fileName)
    }
    /// 获取最后访问时间（LRU）
    public func getLastAccess(for fileName: String) -> Date? {
        heatTracker.getLastAccess(for: fileName)
    }
    /// 获取热度排行（LFU）
    public func topFilesByLFU(limit: Int) -> [String] {
        heatTracker.topFilesByLFU(limit: limit)
    }
    /// 获取热度排行（LRU）
    public func topFilesByLRU(limit: Int) -> [String] {
        heatTracker.topFilesByLRU(limit: limit)
    }
    /// 清空热度统计
    public func resetHeatStats() {
        heatTracker.reset()
    }
    /// 智能预热高频缓存（LFU）
    public func smartPreloadByLFU(limit: Int) {
        let files = topFilesByLFU(limit: limit)
        preloadCache(for: files)
    }
    /// 智能预热高频缓存（LRU）
    public func smartPreloadByLRU(limit: Int) {
        let files = topFilesByLRU(limit: limit)
        preloadCache(for: files)
    }
}
