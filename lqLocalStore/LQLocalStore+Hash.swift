//  Created by xiangduojia on 2026/2/17.

import Foundation
import CryptoKit

public struct CacheHashMeta: Codable {
    public let fileName: String
    public let hash: String
}

extension LQLocalStore {
    /// 计算数据SHA256
    public func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    /// 保存缓存文件hash（以磁盘实际数据为准，兼容压缩/非压缩）
    public func saveHash(for fileName: String, data: Data? = nil) {
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        let diskData = (try? Data(contentsOf: fileURL)) ?? data
        guard let realData = diskData else { return }
        let hash = sha256(realData)
        let meta = CacheHashMeta(fileName: fileName, hash: hash)
        let url = cacheDirectory.appendingPathComponent("\(fileName).hash.meta")
        if let metaData = try? JSONEncoder().encode(meta) {
            try? metaData.write(to: url)
        }
    }
    /// 校验缓存文件hash（以磁盘实际数据为准）
    public func verifyHash(for fileName: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return false }
        let url = cacheDirectory.appendingPathComponent("\(fileName).hash.meta")
        guard let metaData = try? Data(contentsOf: url),
              let meta = try? JSONDecoder().decode(CacheHashMeta.self, from: metaData) else { return false }
        return sha256(data) == meta.hash
    }
    /// 批量校验所有缓存文件hash
    public func verifyAllHashes() -> [String: Bool] {
        let files = (try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path)) ?? []
        var result: [String: Bool] = [:]
        for file in files where !file.hasSuffix(".meta") && !file.hasSuffix(".hash.meta") {
            result[file] = verifyHash(for: file)
        }
        return result
    }
}
