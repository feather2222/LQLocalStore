//  Created by xiangduojia on 2026/2/17.

import Foundation

@available(iOS 13.0, macOS 10.15, *)
extension LQLocalStore {
    public func cacheBatchAtomically(_ items: [(fileName: String, data: Data, expireIn: TimeInterval?, tags: [String]?, priority: Int)]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            cacheBatchAtomically(items) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let err): continuation.resume(throwing: err)
                }
            }
        }
    }
    public func removeBatchAtomically(_ fileNames: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            removeBatchAtomically(fileNames) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let err): continuation.resume(throwing: err)
                }
            }
        }
    }
    // 兼容所有异步接口 async/await
    public func setAsync<T: Codable>(_ value: T, forKey key: String) async {
        await withCheckedContinuation { continuation in
            setAsync(value, forKey: key) { continuation.resume() }
        }
    }
    public func getAsync<T: Codable>(forKey key: String, as type: T.Type) async -> T? {
        await withCheckedContinuation { continuation in
            getAsync(forKey: key, as: type) { result in continuation.resume(returning: result) }
        }
    }
    public func cacheAsync(data: Data, for fileName: String, expireIn seconds: TimeInterval? = nil) async {
        await withCheckedContinuation { continuation in
            cacheAsync(data: data, for: fileName, expireIn: seconds) { continuation.resume() }
        }
    }
    public func getCachedDataAsync(for fileName: String) async -> Data? {
        await withCheckedContinuation { continuation in
            getCachedDataAsync(for: fileName) { data in continuation.resume(returning: data) }
        }
    }
    public func removeCacheAsync(for fileName: String) async {
        await withCheckedContinuation { continuation in
            removeCacheAsync(for: fileName) { continuation.resume() }
        }
    }
    public func getCachedDataAsync(for fileNames: [String]) async -> [String: Data?] {
        await withCheckedContinuation { continuation in
            getCachedDataAsync(for: fileNames) { result in continuation.resume(returning: result) }
        }
    }
    public func removeCacheAsync(for fileNames: [String]) async {
        await withCheckedContinuation { continuation in
            removeCacheAsync(for: fileNames) { continuation.resume() }
        }
    }
}
