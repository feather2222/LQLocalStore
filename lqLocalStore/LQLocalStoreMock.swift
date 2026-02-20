//  Created by xiangduojia on 2026/2/17.

import Foundation

/// Mock 缓存实现，便于单元测试与集成测试
public class LQLocalStoreMock: LQLocalStore {
    private var mockMemory: [String: Data] = [:]
    private var mockMeta: [String: CacheMeta] = [:]
    public var failOnWrite: Bool = false
    public var failOnRead: Bool = false
    public var failOnRemove: Bool = false
    public override func cache(data: Data, for fileName: String, expireIn seconds: TimeInterval? = nil, compress: Bool = true, priority: Int = 0, tags: [String]? = nil) {
        if failOnWrite { return }
        mockMemory[fileName] = data
        mockMeta[fileName] = CacheMeta(expireAt: seconds != nil ? Date().addingTimeInterval(seconds!) : nil, priority: priority, tags: tags)
    }
    public override func getCachedData(for fileName: String) -> Data? {
        if failOnRead { return nil }
        return mockMemory[fileName]
    }
    public override func removeCache(for fileName: String) {
        if failOnRemove { return }
        mockMemory.removeValue(forKey: fileName)
        mockMeta.removeValue(forKey: fileName)
    }
    public override func getTags(for fileName: String) -> [String]? {
        return mockMeta[fileName]?.tags
    }
    public override func getCachedData(for fileNames: [String]) -> [String: Data?] {
        var result: [String: Data?] = [:]
        for name in fileNames { result[name] = getCachedData(for: name) }
        return result
    }
    public override func removeCache(for fileNames: [String]) {
        for name in fileNames { removeCache(for: name) }
    }
    // 可扩展更多 mock 行为...
}
