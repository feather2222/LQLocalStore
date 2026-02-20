//  Created by xiangduojia on 2026/2/17.

import Foundation

public enum CachePriority: Int, Codable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case custom = 99
    public static func < (lhs: CachePriority, rhs: CachePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public protocol CacheEvictionPolicy {
    /// 返回应淘汰的文件名列表（按优先级、热度、权重等自定义）
    func filesToEvict(fileMetas: [(fileName: String, meta: CacheMeta)], totalSize: UInt64, maxSize: UInt64) -> [String]
}

/// 默认优先级+LRU策略
public class DefaultEvictionPolicy: CacheEvictionPolicy {
    public init() {}
    public func filesToEvict(fileMetas: [(fileName: String, meta: CacheMeta)], totalSize: UInt64, maxSize: UInt64) -> [String] {
        // 优先淘汰 priority 低的文件，再按过期时间早的优先
        let sorted = fileMetas.sorted {
            let p1 = $0.meta.priority ?? 0
            let p2 = $1.meta.priority ?? 0
            if p1 != p2 { return p1 < p2 }
            let t1 = $0.meta.expireAt ?? Date.distantPast
            let t2 = $1.meta.expireAt ?? Date.distantPast
            return t1 < t2
        }
        return sorted.map { $0.fileName }
    }
}
