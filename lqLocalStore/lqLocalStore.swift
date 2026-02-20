//  Created by xiangduojia on 2026/2/17.

import Compression
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// lqLocalStore: 本地存储与文件缓存封装，支持缓存过期与自动清理
public class LQLocalStore {
    /// lqLocalStore: 本地存储与文件缓存封装，支持多级缓存、压缩、优先级、监听、批量、并发等
    // MARK: - 内存缓存
    internal let memoryCache = NSCache<NSString, NSData>()
    // MARK: - 命中统计
    private var hitCount: UInt = 0
    private var missCount: UInt = 0
    public static let shared = LQLocalStore()
    internal let fileManager = FileManager.default
    let cacheDirectory: URL
    internal let metaSuffix = ".meta.json"
    let queue = DispatchQueue(label: "lqLocalStore.queue", attributes: .concurrent)
    private var _maxCacheSize: UInt64 = 100 * 1024 * 1024 // 默认100MB
    public var maxCacheSize: UInt64 {
        get { _maxCacheSize }
        set {
            _maxCacheSize = newValue
            cleanIfOverLimit()
        }
    }
    
    /// 缓存变更监听
    public typealias CacheChangeHandler = (_ fileName: String, _ change: CacheChangeType) -> Void
    public enum CacheChangeType { case set, remove, expired }
    var changeHandlers: [UUID: CacheChangeHandler] = [:]
    /// 缓存过期/清理回调
    public typealias CacheExpireHandler = (_ fileName: String) -> Void
    var expireHandlers: [UUID: CacheExpireHandler] = [:]
    
    var logs: [CacheLogEntry] = []
    
    // 可插拔淘汰策略
    public var evictionPolicy: CacheEvictionPolicy = DefaultEvictionPolicy()
    // 热度追踪器
    let heatTracker = CacheHeatTracker()
    
    /// 注册缓存过期/清理回调，返回监听ID
    @discardableResult
    public func addCacheExpireListener(_ handler: @escaping CacheExpireHandler) -> UUID {
        let id = UUID()
        expireHandlers[id] = handler
        return id
    }
    
    /// 移除缓存过期/清理回调
    public func removeCacheExpireListener(_ id: UUID) {
        expireHandlers.removeValue(forKey: id)
    }
    
    /// 支持命名空间和自定义容量的初始化
    public init(namespace: String? = nil, maxCacheSize: UInt64? = nil) {
        if let dir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            if let ns = namespace, !ns.isEmpty {
                cacheDirectory = dir.appendingPathComponent("lqLocalStoreCache_" + ns, isDirectory: true)
            } else {
                cacheDirectory = dir.appendingPathComponent("lqLocalStoreCache", isDirectory: true)
            }
            if !fileManager.fileExists(atPath: cacheDirectory.path) {
                try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            }
        } else {
            fatalError("无法获取缓存目录")
        }
        if let max = maxCacheSize { self.maxCacheSize = max }
        cleanExpiredCache()
        cleanIfOverLimit()
    }
    
    // MARK: - Key-Value 存储（UserDefaults 封装）
    public func set<T: Codable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    public func get<T: Codable>(forKey key: String, as type: T.Type) -> T? {
        if let data = UserDefaults.standard.data(forKey: key) {
            return try? JSONDecoder().decode(type, from: data)
        }
        return nil
    }
    
    // MARK: - Key-Value 异步 API
    public func setAsync<T: Codable>(_ value: T, forKey key: String, completion: (() -> Void)? = nil) {
        queue.async {
            self.set(value, forKey: key)
            DispatchQueue.main.async { completion?() }
        }
    }
    
    public func getAsync<T: Codable>(forKey key: String, as type: T.Type, completion: @escaping (T?) -> Void) {
        queue.async {
            let result = self.get(forKey: key, as: type)
            DispatchQueue.main.async { completion(result) }
        }
    }
    
    /// 缓存数据到文件，可设置过期时间（秒）
    /// 缓存数据（自动压缩存储）
    /// 缓存数据（支持优先级，默认0，越大越高）
    /// 支持为缓存项设置标签
    public func cache(data: Data, for fileName: String, expireIn seconds: TimeInterval? = nil, compress: Bool = true, priority: Int = 0, tags: [String]? = nil) {
        let storeData = compress ? (self.compress(data) ?? data) : data
        // 写入内存缓存（原始数据）
        memoryCache.setObject(data as NSData, forKey: fileName as NSString)
        // 写入磁盘（压缩数据）
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        try? storeData.write(to: fileURL)
        let meta = CacheMeta(expireAt: seconds != nil ? Date().addingTimeInterval(seconds!) : nil, priority: priority, tags: tags)
        saveMeta(meta, for: fileName)
        cleanIfOverLimit()
        log("cache", fileName: fileName)
        notifyChange(fileName: fileName, change: .set)
    }
    /// 获取缓存项标签
    public func getTags(for fileName: String) -> [String]? {
        return loadMeta(for: fileName)?.tags
    }
    
    /// 批量获取带有指定标签的缓存文件名
    public func getFileNames(withTag tag: String) -> [String] {
        let files = (try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path)) ?? []
        var result: [String] = []
        for file in files where !file.hasSuffix(metaSuffix) {
            if let tags = loadMeta(for: file)?.tags, tags.contains(tag) {
                result.append(file)
            }
        }
        return result
    }
    
    /// 批量移除指定标签的缓存
    public func removeCache(withTag tag: String) {
        let files = getFileNames(withTag: tag)
        removeCache(for: files)
    }
    /// 检查并清理超出容量的缓存（LRU）
    internal func cleanIfOverLimit() {
        var total = currentCacheSize()
        guard total > maxCacheSize else { return }
        let files = (try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [URLResourceKey.fileSizeKey], options: [])) ?? []
        let dataFiles = files.filter { !$0.lastPathComponent.hasSuffix(metaSuffix) }
        var fileMetas: [(String, CacheMeta, UInt64)] = []
        for url in dataFiles {
            let fileName = url.lastPathComponent
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { UInt64($0) } ?? 0
            if let meta = loadMeta(for: fileName) {
                fileMetas.append((fileName, meta, size))
            }
        }
        // 按策略顺序淘汰
        let evictOrder = evictionPolicy.filesToEvict(fileMetas: fileMetas.map { ($0.0, $0.1) }, totalSize: total, maxSize: maxCacheSize)
        for file in evictOrder {
            if total <= maxCacheSize { break }
            let url = cacheDirectory.appendingPathComponent(file)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { UInt64($0) } ?? 0
            try? fileManager.removeItem(at: url)
            let metaURL = cacheDirectory.appendingPathComponent(file + metaSuffix)
            try? fileManager.removeItem(at: metaURL)
            total = currentCacheSize() // 每次都重新计算，确保准确
        }
    }
    
    /// 当前缓存目录已用空间
    public func currentCacheSize() -> UInt64 {
        let files = (try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey], options: [])) ?? []
        var total: UInt64 = 0
        for url in files where !url.lastPathComponent.hasSuffix(metaSuffix) {
            total += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { UInt64($0) } ?? 0
        }
        return total
    }
    
    /// 异步缓存数据到文件
    public func cacheAsync(data: Data, for fileName: String, expireIn seconds: TimeInterval? = nil, completion: (() -> Void)? = nil) {
        queue.async {
            self.cache(data: data, for: fileName, expireIn: seconds)
            DispatchQueue.main.async { completion?() }
        }
    }
    
    /// 获取缓存数据，自动判断是否过期
    /// 获取缓存数据（自动解压）
    public func getCachedData(for fileName: String) -> Data? {
        heatTracker.recordAccess(for: fileName)
        // 查元数据，判断是否过期
        if let meta = loadMeta(for: fileName), let expireAt = meta.expireAt, expireAt < Date() {
            removeCache(for: fileName)
            notifyExpire(fileName: fileName)
            missCount += 1
            return nil
        }
        // 优先查内存缓存
        if let memData = memoryCache.object(forKey: fileName as NSString) as Data? {
            hitCount += 1
            return memData
        }
        // 查磁盘
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: fileURL) {
            let decompressed = self.decompress(data) ?? data
            // 命中磁盘后写入内存（解压后数据）
            memoryCache.setObject(decompressed as NSData, forKey: fileName as NSString)
            hitCount += 1
            return decompressed
        } else {
            missCount += 1
            return nil
        }
    }
    // MARK: - 命中统计接口
    /// 获取缓存命中次数
    public func cacheHitCount() -> UInt { hitCount }
    
    /// 获取缓存未命中次数
    public func cacheMissCount() -> UInt { missCount }
    
    /// 获取缓存命中率（0~1）
    public func cacheHitRate() -> Double {
        let total = hitCount + missCount
        return total == 0 ? 0 : Double(hitCount) / Double(total)
    }
    
    /// 重置命中统计
    public func resetCacheHitStats() {
        hitCount = 0
        missCount = 0
    }
    
    /// 异步获取缓存数据
    public func getCachedDataAsync(for fileName: String, completion: @escaping (Data?) -> Void) {
        heatTracker.recordAccess(for: fileName)
        queue.async {
            let data = self.getCachedData(for: fileName)
            DispatchQueue.main.async { completion(data) }
        }
    }
    
    /// 移除缓存
    public func removeCache(for fileName: String) {
        // 移除内存缓存
        memoryCache.removeObject(forKey: fileName as NSString)
        // 移除磁盘缓存
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
        removeMeta(for: fileName)
        log("remove", fileName: fileName)
        notifyChange(fileName: fileName, change: .remove)
    }
    
    /// 异步移除缓存
    public func removeCacheAsync(for fileName: String, completion: (() -> Void)? = nil) {
        queue.async {
            self.removeCache(for: fileName)
            DispatchQueue.main.async { completion?() }
        }
    }
    
    /// 清理所有已过期缓存
    public func cleanExpiredCache() {
        let files = (try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path)) ?? []
        for file in files where !file.hasSuffix(metaSuffix) {
            if let meta = loadMeta(for: file), let expireAt = meta.expireAt, expireAt < Date() {
                removeCache(for: file)
                notifyExpire(fileName: file)
            }
        }
    }
    
    /// 异步清理所有已过期缓存
    public func cleanExpiredCacheAsync(completion: (() -> Void)? = nil) {
        queue.async {
            self.cleanExpiredCache()
            DispatchQueue.main.async { completion?() }
        }
    }
    
    private func metaURL(for fileName: String) -> URL {
        cacheDirectory.appendingPathComponent(fileName + metaSuffix)
    }
    
    internal func saveMeta(_ meta: CacheMeta, for fileName: String) {
        let url = metaURL(for: fileName)
        if let data = try? JSONEncoder().encode(meta) {
            try? data.write(to: url)
        }
    }
    
    internal func loadMeta(for fileName: String) -> CacheMeta? {
        let url = metaURL(for: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CacheMeta.self, from: data)
    }
    
    internal func removeMeta(for fileName: String) {
        let url = metaURL(for: fileName)
        try? fileManager.removeItem(at: url)
    }
    
    // MARK: - 批量操作
    /// 批量获取缓存数据
    public func getCachedData(for fileNames: [String]) -> [String: Data?] {
        for name in fileNames { heatTracker.recordAccess(for: name) }
        var result: [String: Data?] = [:]
        for name in fileNames {
            result[name] = self.getCachedData(for: name)
        }
        return result
    }
    
    /// 异步批量获取缓存数据
    public func getCachedDataAsync(for fileNames: [String], completion: @escaping ([String: Data?]) -> Void) {
        queue.async {
            let result = self.getCachedData(for: fileNames)
            DispatchQueue.main.async { completion(result) }
        }
    }
    
    /// 批量移除缓存
    public func removeCache(for fileNames: [String]) {
        for name in fileNames {
            self.removeCache(for: name)
        }
    }
    
    /// 异步批量移除缓存
    public func removeCacheAsync(for fileNames: [String], completion: (() -> Void)? = nil) {
        queue.async {
            self.removeCache(for: fileNames)
            DispatchQueue.main.async { completion?() }
        }
    }
    
    // MARK: - Swift Concurrency 支持
    // async/await 相关接口见 LQLocalStore+AsyncAwait.swift
    
    // async/await 相关接口见 LQLocalStore+AsyncAwait.swift
    
#if canImport(UIKit)
    /// 缓存 UIImage
    public func cache(image: UIImage, for fileName: String, expireIn seconds: TimeInterval? = nil) {
        if let data = image.pngData() {
            cache(data: data, for: fileName, expireIn: seconds)
        }
    }
    /// 获取 UIImage
    public func getCachedImage(for fileName: String) -> UIImage? {
        guard let data = getCachedData(for: fileName) else { return nil }
        return UIImage(data: data)
    }
#endif
    
    /// 缓存字符串
    public func cache(string: String, for fileName: String, expireIn seconds: TimeInterval? = nil) {
        if let data = string.data(using: .utf8) {
            cache(data: data, for: fileName, expireIn: seconds)
        }
    }
    /// 获取字符串
    public func getCachedString(for fileName: String) -> String? {
        guard let data = getCachedData(for: fileName) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// 缓存 JSON 对象（泛型）
    public func cacheJSON<T: Encodable>(_ value: T, for fileName: String, expireIn seconds: TimeInterval? = nil) {
        if let data = try? JSONEncoder().encode(value) {
            cache(data: data, for: fileName, expireIn: seconds)
        }
    }
    /// 获取 JSON 对象（泛型）
    public func getCachedJSON<T: Decodable>(for fileName: String, as type: T.Type) -> T? {
        guard let data = getCachedData(for: fileName) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

