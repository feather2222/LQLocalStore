//  Created by xiangduojia on 2026/2/17.

import Foundation
import Compression

extension LQLocalStore {
    func compress(_ data: Data) -> Data? {
        if #available(iOS 13.0, macOS 10.15, *) {
            guard let compressed = (try? (data as NSData).compressed(using: .lz4)) as Data? else { return nil }
            return compressed
        } else {
            return nil
        }
    }
    func decompress(_ data: Data) -> Data? {
        if #available(iOS 13.0, macOS 10.15, *) {
            guard let decompressed = (try? (data as NSData).decompressed(using: .lz4)) as Data? else { return nil }
            return decompressed
        } else {
            return nil
        }
    }
}
