//  Created by xiangduojia on 2026/2/17.

import Foundation

extension LQLocalStore {
    public func getCacheLogs(limit: Int = 100) -> [CacheLogEntry] {
        return Array(logs.suffix(limit))
    }
    public func clearCacheLogs() {
        logs.removeAll()
    }
    func log(_ action: String, fileName: String, info: String? = nil) {
        logs.append(CacheLogEntry(time: Date(), action: action, fileName: fileName, info: info))
    }
}
