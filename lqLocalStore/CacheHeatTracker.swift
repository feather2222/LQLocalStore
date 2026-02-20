//  Created by xiangduojia on 2026/2/17.

import Foundation

/// 缓存热度追踪（支持LFU/LRU/自定义）
public class CacheHeatTracker {
    private var accessCount: [String: Int] = [:]
    private var lastAccess: [String: Date] = [:]
    private let queue = DispatchQueue(label: "CacheHeatTracker.queue", attributes: .concurrent)
    
    /// 记录访问
    public func recordAccess(for fileName: String) {
        queue.async(flags: .barrier) {
            self.accessCount[fileName, default: 0] += 1
            self.lastAccess[fileName] = Date()
        }
    }
    /// 获取访问次数
    public func getAccessCount(for fileName: String) -> Int {
        queue.sync { accessCount[fileName] ?? 0 }
    }
    /// 获取最后访问时间
    public func getLastAccess(for fileName: String) -> Date? {
        queue.sync { lastAccess[fileName] }
    }
    /// 获取热度排行（LFU，访问次数降序）
    public func topFilesByLFU(limit: Int) -> [String] {
        queue.sync {
            accessCount.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
        }
    }
    /// 获取热度排行（LRU，最近访问时间降序）
    public func topFilesByLRU(limit: Int) -> [String] {
        queue.sync {
            lastAccess.sorted { ($0.value) > ($1.value) }.prefix(limit).map { $0.key }
        }
    }
    /// 清空统计
    public func reset() {
        queue.async(flags: .barrier) {
            self.accessCount.removeAll()
            self.lastAccess.removeAll()
        }
    }
}
