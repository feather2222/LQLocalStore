//  Created by xiangduojia on 2026/2/17.
//  lqLocalStoreTests.swift
//  lqLocalStoreTests
//
//  Created by xiangduojia on 2026/2/19.
//

import XCTest
@testable import lqLocalStore

final class lqLocalStoreTests: XCTestCase {
    var store: LQLocalStore!
    override func setUp() {
        super.setUp()
        store = LQLocalStore(namespace: "test", maxCacheSize: 1024*1024)
    }
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    func testCacheAndGetData() {
        let data = "hello".data(using: .utf8)!
        store.cache(data: data, for: "file1")
        let result = store.getCachedData(for: "file1")
        XCTAssertEqual(result, data)
    }
    func testRemoveCache() {
        let data = Data([1,2,3])
        store.cache(data: data, for: "file2")
        store.removeCache(for: "file2")
        let result = store.getCachedData(for: "file2")
        XCTAssertNil(result)
    }
    func testExpire() {
        let data = Data([4,5,6])
        store.cache(data: data, for: "file3", expireIn: 0.1)
        sleep(1)
        let result = store.getCachedData(for: "file3")
        XCTAssertNil(result)
    }
    func testTagQuota() {
        let data = Data(repeating: 1, count: 512*1024)
        store.setQuota(512*1024, forTag: "tag1")
        store.cache(data: data, for: "file4", tags: ["tag1"])
        store.cache(data: data, for: "file5", tags: ["tag1"])
        store.cleanIfTagOverLimit("tag1")
        let files = store.getFileNames(withTag: "tag1")
        XCTAssertTrue(files.count <= 1)
    }
    func testPriorityEviction() {
        let data = Data(repeating: 2, count: 256*1024)
        store.cache(data: data, for: "file6", priority: 1)
        store.cache(data: data, for: "file7", priority: 0)
        store.maxCacheSize = 256*1024
        store.cleanIfOverLimit()
        let r1 = store.getCachedData(for: "file6")
        let r2 = store.getCachedData(for: "file7")
        XCTAssertNotNil(r1)
        XCTAssertNil(r2)
    }
    func testMock() {
        let mock = LQLocalStoreMock()
        let data = Data([9,9,9])
        mock.cache(data: data, for: "mockfile")
        let result = mock.getCachedData(for: "mockfile")
        XCTAssertEqual(result, data)
    }
    func testBatchAtomic() {
        let items: [(fileName: String, data: Data, expireIn: TimeInterval?, tags: [String]?, priority: Int)] = [
            (fileName: "b1", data: Data([1]), expireIn: nil, tags: nil, priority: 0),
            (fileName: "b2", data: Data([2]), expireIn: nil, tags: nil, priority: 0)
        ]
        let exp = expectation(description: "batch")
        store.cacheBatchAtomically(items) { result in
            switch result {
            case .success: break
            case .failure: XCTFail()
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
        XCTAssertEqual(store.getCachedData(for: "b1"), Data([1]))
        XCTAssertEqual(store.getCachedData(for: "b2"), Data([2]))
    }
    func testAsyncAwait() async {
        let data = Data([3,3,3])
        await store.cacheAsync(data: data, for: "a1")
        let result = await store.getCachedDataAsync(for: "a1")
        XCTAssertEqual(result, data)
    }
    func testCompression() {
        let data = Data(repeating: 7, count: 1024)
        let compressed = store.compress(data)
        let decompressed = store.decompress(compressed!)
        XCTAssertEqual(decompressed, data)
    }
    func testChunkAndMerge() {
        let total = 4
        let chunkSize = 3
        let fileName = "bigfile"
        let all = Data([1,2,3,4,5,6,7,8,9,10,11,12])
        for i in 0..<total {
            let chunk = all.subdata(in: i*chunkSize..<(i+1)*chunkSize)
            store.cacheChunk(data: chunk, for: fileName, chunkIndex: i, totalChunks: total, chunkSize: chunkSize, fileSize: all.count)
        }
        let exp = expectation(description: "merge")
        store.mergeChunks(for: fileName) { success in
            XCTAssertTrue(success)
            let merged = self.store.getCachedData(for: fileName)
            XCTAssertEqual(merged, all)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
    }
    func testMonitorSnapshot() {
        let snap = store.getMonitorSnapshot()
        XCTAssertGreaterThanOrEqual(snap.totalCacheSize, 0)
        XCTAssertGreaterThan(snap.maxCacheSize, 0)
    }
    func testAlert() {
        class Handler: CacheAlertHandler { var called = false; func cacheUsageAlert(current: UInt64, max: UInt64) { called = true } }
        let handler = Handler()
        store.alertThreshold = 0.0001
        store.alertHandler = handler
        store.cache(data: Data(repeating: 1, count: 1), for: "alertfile")
        store.checkAndAlertIfNeeded()
        XCTAssertTrue(handler.called)
    }
    func testHash() {
        let data = Data([8,8,8])
        store.cache(data: data, for: "hashfile")
        store.saveHash(for: "hashfile", data: data)
        XCTAssertTrue(store.verifyHash(for: "hashfile"))
    }
    func testConcurrency() {
        let exp = expectation(description: "concurrent")
        exp.expectedFulfillmentCount = 10
        store.setThreadPoolConcurrency(4)
        for i in 0..<10 {
            let d = Data([UInt8(i)])
            store.threadPool.async {
                self.store.cache(data: d, for: "c\(i)")
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 3)
    }
    func testListener() {
        var changed = false
        let id = store.addCacheChangeListener { file, change in
            if file == "listenfile" && change == .set { changed = true }
        }
        store.cache(data: Data([1]), for: "listenfile")
        XCTAssertTrue(changed)
        store.removeCacheChangeListener(id)
    }
    func testLog() {
        store.cache(data: Data([2]), for: "logfile")
        let logs = store.getCacheLogs()
        XCTAssertTrue(logs.contains { $0.fileName == "logfile" })
        store.clearCacheLogs()
        XCTAssertEqual(store.getCacheLogs().count, 0)
    }
    func testEvictionPolicy() {
        class CustomPolicy: CacheEvictionPolicy {
            func filesToEvict(fileMetas: [(fileName: String, meta: CacheMeta)], totalSize: UInt64, maxSize: UInt64) -> [String] {
                return fileMetas.map { $0.fileName }.reversed()
            }
        }
        store.evictionPolicy = CustomPolicy()
        let data = Data(repeating: 1, count: 512*1024)
        store.cache(data: data, for: "e1")
        store.cache(data: data, for: "e2")
        store.maxCacheSize = 512*1024
        store.cleanIfOverLimit()
        let r1 = store.getCachedData(for: "e1")
        let r2 = store.getCachedData(for: "e2")
        XCTAssertTrue((r1 == nil) != (r2 == nil))
    }
    func testExpirePolicy() {
        class CustomExpire: CacheExpirePolicy {
            func expireDate(for fileName: String, meta: CacheMeta) -> Date? { return Date().addingTimeInterval(-1) }
        }
        store.expirePolicy = CustomExpire()
        store.cache(data: Data([1]), for: "exfile")
        store.cleanCustomExpiredCache()
        let r = store.getCachedData(for: "exfile")
        XCTAssertNil(r)
    }
}
