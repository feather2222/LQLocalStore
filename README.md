# lqLocalStore

本地高性能 Key-Value/文件缓存库，支持多级缓存、批量、标签、优先级、压缩、详细日志、Mock、分片、自动扩容、监控、可插拔策略等高级特性，适用于 iOS/macOS Swift 项目。

## 特性
- 支持内存+磁盘多级缓存，自动过期与清理
- 支持批量操作、异步/并发、分片与合并
- 支持标签分组、容量配额、优先级淘汰
- 支持压缩存储、哈希校验、详细日志、监控快照
- 支持自定义淘汰/过期策略、Mock 测试、自动扩容
- 支持 Swift async/await、可插拔扩展

## 快速开始
```swift
let store = LQLocalStore(namespace: "demo", maxCacheSize: 10*1024*1024)
// 存数据
store.cache(data: data, for: "file1", expireIn: 60, tags: ["img"], priority: 1)
// 取数据
let data = store.getCachedData(for: "file1")
// 移除
store.removeCache(for: "file1")
```

## 高级用法
- 批量原子缓存：
```swift
store.cacheBatchAtomically(items) { result in ... }
```
- 并发批量：
```swift
store.cacheBatchConcurrent(items) { ... }
```
- 标签/配额/优先级：
```swift
store.setQuota(1024*1024, forTag: "tag1")
store.cache(data: data, for: "f", tags: ["tag1"], priority: 2)
```
- 日志与监控：
```swift
let logs = store.getCacheLogs()
let snap = store.getMonitorSnapshot()
```
- Mock 测试：
```swift
let mock = LQLocalStoreMock()
mock.cache(data: data, for: "mockfile")
```

## 主要接口
- `cache(data:for:expireIn:compress:priority:tags:)` 缓存数据
- `getCachedData(for:)` 获取数据
- `removeCache(for:)` 移除数据
- `cacheBatchAtomically`/`cacheBatchConcurrent` 批量操作
- `setQuota(forTag:)`/`cleanIfTagOverLimit` 标签配额
- `getCacheLogs`/`clearCacheLogs` 日志
- `getMonitorSnapshot` 监控
- `saveHash`/`verifyHash` 哈希校验
- `evictionPolicy`/`expirePolicy` 可插拔策略

## 测试覆盖
- 所有核心功能、批量、标签、优先级、压缩、Mock、分片、自动扩容、监控、淘汰/过期策略、日志、哈希、并发等均有专项单元测试

## 目录结构
- lqLocalStore.swift 主类
- LQLocalStore+*.swift 功能扩展
- lqLocalStoreTests/ 单元测试

## 许可证
MIT License
