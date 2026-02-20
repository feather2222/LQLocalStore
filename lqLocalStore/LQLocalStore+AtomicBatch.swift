//  Created by xiangduojia on 2026/2/17.

import Foundation

public enum BatchOperationError: Error {
    case partialFailure(failedFiles: [String])
}

extension LQLocalStore {
    /// 原子批量缓存（全部成功才提交，否则回滚）
    public func cacheBatchAtomically(_ items: [(fileName: String, data: Data, expireIn: TimeInterval?, tags: [String]?, priority: Int)], completion: @escaping (Result<Void, BatchOperationError>) -> Void) {
        queue.async(flags: .barrier) {
            var written: [String] = []
            var failed: [String] = []
            for item in items {
                let fileURL = self.cacheDirectory.appendingPathComponent(item.fileName)
                do {
                    try item.data.write(to: fileURL)
                    let meta = CacheMeta(expireAt: item.expireIn != nil ? Date().addingTimeInterval(item.expireIn!) : nil, priority: item.priority, tags: item.tags)
                    self.saveMeta(meta, for: item.fileName)
                    self.memoryCache.setObject(item.data as NSData, forKey: item.fileName as NSString)
                    written.append(item.fileName)
                } catch {
                    failed.append(item.fileName)
                }
            }
            if failed.isEmpty {
                DispatchQueue.main.async { completion(.success(())) }
            } else {
                // 回滚已写入
                for file in written {
                    let url = self.cacheDirectory.appendingPathComponent(file)
                    try? self.fileManager.removeItem(at: url)
                    self.removeMeta(for: file)
                    self.memoryCache.removeObject(forKey: file as NSString)
                }
                DispatchQueue.main.async { completion(.failure(.partialFailure(failedFiles: failed))) }
            }
        }
    }
    /// 原子批量移除
    public func removeBatchAtomically(_ fileNames: [String], completion: @escaping (Result<Void, BatchOperationError>) -> Void) {
        queue.async(flags: .barrier) {
            var failed: [String] = []
            for file in fileNames {
                let url = self.cacheDirectory.appendingPathComponent(file)
                do {
                    try self.fileManager.removeItem(at: url)
                    self.removeMeta(for: file)
                    self.memoryCache.removeObject(forKey: file as NSString)
                } catch {
                    failed.append(file)
                }
            }
            if failed.isEmpty {
                DispatchQueue.main.async { completion(.success(())) }
            } else {
                DispatchQueue.main.async { completion(.failure(.partialFailure(failedFiles: failed))) }
            }
        }
    }
}
