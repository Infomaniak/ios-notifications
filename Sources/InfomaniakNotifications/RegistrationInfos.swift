/*
 Infomaniak Notifications - iOS
 Copyright (C) 2023 Infomaniak Network SA

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

#if canImport(UIKit)
import UIKit
#else
import Foundation
#endif

struct RegistrationInfos: Encodable {
    let os = "ios"
    let token: String
    let model: String
    let name: String
    let isSandboxed: Bool
    var topics: [Topic]

    @MainActor
    init(token: String, topics: [Topic]) {
        self.topics = topics
        self.token = token

        #if canImport(UIKit)
        model = UIDevice().model
        name = UIDevice().name
        #else
        model = "Mac"
        name = ProcessInfo().hostName
        #endif

        #if DEBUG
        isSandboxed = true
        #else
        isSandboxed = false
        #endif
    }
}
