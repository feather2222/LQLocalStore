//  Created by xiangduojia on 2026/2/17.

import Foundation

public class LQThreadPool {
    private let queue: DispatchQueue
    public let maxConcurrent: Int
    private let semaphore: DispatchSemaphore
    public init(label: String, maxConcurrent: Int) {
        self.maxConcurrent = maxConcurrent
        self.queue = DispatchQueue(label: label, attributes: .concurrent)
        self.semaphore = DispatchSemaphore(value: maxConcurrent)
    }
    public func async(_ block: @escaping () -> Void) {
        semaphore.wait()
        queue.async {
            block()
            self.semaphore.signal()
        }
    }
}

extension LQLocalStore {
    /// 可自定义并发度的线程池（用于高并发批量操作）
    public var threadPool: LQThreadPool {
        get { _threadPoolQueue.sync { _threadPool } }
        set { _threadPoolQueue.async(flags: .barrier) { self._threadPool = newValue } }
    }
    private static var _threadPool: LQThreadPool = LQThreadPool(label: "lqLocalStore.threadPool", maxConcurrent: 4)
    private static let _threadPoolQueue = DispatchQueue(label: "lqLocalStore.threadPool.queue", attributes: .concurrent)
    private var _threadPool: LQThreadPool {
        get { Self._threadPoolQueue.sync { Self._threadPool } }
        set { Self._threadPoolQueue.async(flags: .barrier) { Self._threadPool = newValue } }
    }
    private var _threadPoolQueue: DispatchQueue { Self._threadPoolQueue }
    /// 设置并发度
    public func setThreadPoolConcurrency(_ count: Int) {
        threadPool = LQThreadPool(label: "lqLocalStore.threadPool", maxConcurrent: count)
    }
    /// 并发批量缓存（线程池调度）
    public func cacheBatchConcurrent(_ items: [(fileName: String, data: Data, expireIn: TimeInterval?, tags: [String]?, priority: Int)], completion: (() -> Void)? = nil) {
        let group = DispatchGroup()
        for item in items {
            threadPool.async {
                self.cache(data: item.data, for: item.fileName, expireIn: item.expireIn, priority: item.priority, tags: item.tags)
                group.leave()
            }
            group.enter()
        }
        group.notify(queue: .main) { completion?() }
    }
}
