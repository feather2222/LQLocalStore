//  Created by xiangduojia on 2026/2/17.

import Foundation

extension LQLocalStore {
    /// 预加载指定缓存文件到内存（同步）
    public func preloadCache(for fileNames: [String]) {
        for name in fileNames {
            _ = getCachedData(for: name)
        }
    }
    /// 异步预加载指定缓存文件到内存
    public func preloadCacheAsync(for fileNames: [String], completion: (() -> Void)? = nil) {
        queue.async {
            self.preloadCache(for: fileNames)
            DispatchQueue.main.async { completion?() }
        }
    }
}
