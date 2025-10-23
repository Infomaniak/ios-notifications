/*
 Infomaniak Notifications - iOS
 Copyright (C) 2025 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

public struct Topic: ExpressibleByStringLiteral, Sendable, Codable, Hashable, Equatable {
    let rawValue: String

    public init(stringLiteral value: StringLiteralType) {
        rawValue = value
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }
}

extension Collection where Element == Topic {
    func isEqualToTopics(_ other: [Topic]) -> Bool {
        let sortedSelf = sorted { $0.rawValue < $1.rawValue }
        let sortedOther = other.sorted { $0.rawValue < $1.rawValue }
        return sortedSelf == sortedOther
    }
}
