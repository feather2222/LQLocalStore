//  Created by xiangduojia on 2026/2/17.

import Foundation

extension LQLocalStore {
    @discardableResult
    public func addCacheChangeListener(_ handler: @escaping CacheChangeHandler) -> UUID {
        let id = UUID()
        changeHandlers[id] = handler
        return id
    }
    public func removeCacheChangeListener(_ id: UUID) {
        changeHandlers.removeValue(forKey: id)
    }
    func notifyChange(fileName: String, change: CacheChangeType) {
        for handler in changeHandlers.values {
            handler(fileName, change)
        }
    }
    func notifyExpire(fileName: String) {
        for handler in expireHandlers.values {
            handler(fileName)
        }
    }
}
