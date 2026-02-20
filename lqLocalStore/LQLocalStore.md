# LQLocalStore API 文档

## 简介
LQLocalStore 是一款高性能、可扩展的本地缓存/文件存储库，支持多级缓存、批量、标签、优先级、压缩、并发、监控、Mock、分片、自动扩容等高级特性，适用于 iOS/macOS/Swift 项目。

## 快速开始
```swift
let store = LQLocalStore()
store.cache(data: myData, for: "file1")
let data = store.getCachedData(for: "file1")
store.removeCache(for: "file1")
```

## 主要功能
- Key-Value 存储与文件缓存
- 缓存过期、自动清理、优先级淘汰
- 标签分组、批量操作、容量/标签限额
- 压缩、分片、断点续传
- 并发安全、线程池、原子批量
- 缓存热度统计与智能预热（LFU/LRU）
- 详细监控与可视化、用量预警
- Mock 支持、自动化测试
- 可插拔淘汰/过期/扩容策略

## 常用 API
### 缓存基本操作
```swift
store.cache(data: data, for: "file1", expireIn: 3600, tags: ["user"], priority: 1)
let data = store.getCachedData(for: "file1")
store.removeCache(for: "file1")
```
### 标签与批量
```swift
store.setQuota(10*1024*1024, forTag: "user")
let tagFiles = store.getFileNames(withTag: "user")
store.removeCache(for: tagFiles)
```
### 并发与线程池
```swift
store.setThreadPoolConcurrency(8)
store.cacheBatchConcurrent(items) { print("done") }
```
### 原子批量与 async/await
```swift
try await store.cacheBatchAtomically(items)
```
### 监控与预警
```swift
let snap = store.getMonitorSnapshot()
store.alertThreshold = 0.9
store.alertHandler = myHandler
```
### 分片与断点续传
```swift
store.cacheChunk(data: chunk, for: "bigfile", chunkIndex: 0, totalChunks: 10, chunkSize: 1024*1024, fileSize: 10*1024*1024)
store.mergeChunks(for: "bigfile") { success in }
```
### Mock 用法
```swift
let mock = LQLocalStoreMock()
mock.cache(data: data, for: "mockfile")
```

## 配置说明
- `maxCacheSize`：全局容量上限，超限自动清理
- `tagQuota`：标签分组容量上限
- `evictionPolicy`：自定义淘汰策略
- `expirePolicy`：自定义过期策略
- `alertThreshold`：用量预警阈值
- `threadPool`：自定义线程池并发度

## 扩展与自定义
- 实现 `CacheEvictionPolicy`、`CacheExpirePolicy`、`CacheAlertHandler` 可自定义淘汰/过期/预警策略
- 可扩展分片、加密、远程同步等高级特性

## 兼容性
- 支持 iOS 11+/macOS 10.13+
- 完美兼容 Swift Concurrency (async/await)

## 贡献与测试
- 支持 Mock 测试、单元测试、集成测试
- 欢迎 PR 与建议
