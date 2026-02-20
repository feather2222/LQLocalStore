//  Created by xiangduojia on 2026/2/17.

import Foundation

public struct CacheMeta: Codable {
    let expireAt: Date?
    let priority: Int?
    let tags: [String]?
}
