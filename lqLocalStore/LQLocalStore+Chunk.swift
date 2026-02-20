//  Created by xiangduojia on 2026/2/17.

import Foundation

public struct ChunkMeta: Codable {
    public let totalChunks: Int
    public let chunkSize: Int
    public let fileName: String
    public let fileSize: Int
}

extension LQLocalStore {
    /// 分片写入（支持断点续传）
    public func cacheChunk(data: Data, for fileName: String, chunkIndex: Int, totalChunks: Int, chunkSize: Int, fileSize: Int, completion: (() -> Void)? = nil) {
        let chunkFile = "\(fileName).chunk.\(chunkIndex)"
        let url = cacheDirectory.appendingPathComponent(chunkFile)
        try? data.write(to: url)
        if chunkIndex == 0 {
            let meta = ChunkMeta(totalChunks: totalChunks, chunkSize: chunkSize, fileName: fileName, fileSize: fileSize)
            let metaURL = cacheDirectory.appendingPathComponent("\(fileName).chunk.meta")
            if let metaData = try? JSONEncoder().encode(meta) {
                try? metaData.write(to: metaURL)
            }
        }
        DispatchQueue.main.async { completion?() }
    }
    /// 合并分片为完整文件
    public func mergeChunks(for fileName: String, completion: ((Bool) -> Void)? = nil) {
        let metaURL = cacheDirectory.appendingPathComponent("\(fileName).chunk.meta")
        guard let metaData = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(ChunkMeta.self, from: metaData) else {
            completion?(false); return
        }
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        let handle = try? FileHandle(forWritingTo: fileURL)
        if handle == nil { FileManager.default.createFile(atPath: fileURL.path, contents: nil) }
        guard let fileHandle = try? FileHandle(forWritingTo: fileURL) else { completion?(false); return }
        fileHandle.truncateFile(atOffset: 0)
        for i in 0..<meta.totalChunks {
            let chunkFile = cacheDirectory.appendingPathComponent("\(fileName).chunk.\(i)")
            if let chunkData = try? Data(contentsOf: chunkFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(chunkData)
            } else {
                fileHandle.closeFile()
                completion?(false); return
            }
        }
        fileHandle.closeFile()
        // 清理分片
        for i in 0..<meta.totalChunks {
            let chunkFile = cacheDirectory.appendingPathComponent("\(fileName).chunk.\(i)")
            try? FileManager.default.removeItem(at: chunkFile)
        }
        try? FileManager.default.removeItem(at: metaURL)
        DispatchQueue.main.async { completion?(true) }
    }
    /// 查询已上传分片索引
    public func uploadedChunkIndexes(for fileName: String, totalChunks: Int) -> [Int] {
        var result: [Int] = []
        for i in 0..<totalChunks {
            let chunkFile = cacheDirectory.appendingPathComponent("\(fileName).chunk.\(i)")
            if FileManager.default.fileExists(atPath: chunkFile.path) {
                result.append(i)
            }
        }
        return result
    }
}
