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

import Foundation
import InfomaniakCore
import InfomaniakDI

public extension Endpoint {
    static var registerDevice: Endpoint {
        return .baseV1.appending(path: "/devices/register")
    }
}

public extension ApiFetcher {
    func registerForNotifications(registrationInfos: RegistrationInfos) async throws -> Bool {
        try await perform(request: authenticatedRequest(.registerDevice, method: .post, parameters: registrationInfos)).data
    }
}

actor UserNotificationTokenStore {
    private let registeredUserAPNSTokensKey = "registeredUserAPNSTokens"
    var registeredUsers = [String: String]()

    init() {
        if let registeredUsers = UserDefaults.standard.dictionary(forKey: registeredUserAPNSTokensKey) as? [String: String] {
            self.registeredUsers = registeredUsers
        }
    }

    func registerUser(id: Int, apnsToken: String) {
        registeredUsers["\(id)"] = apnsToken
        UserDefaults.standard.set(registeredUsers, forKey: registeredUserAPNSTokensKey)
    }

    func apnsTokenForUser(id: Int) -> String? {
        return registeredUsers["\(id)"]
    }

    func removeToken(for userId: Int) {
        registeredUsers["\(userId)"] = nil
        UserDefaults.standard.set(registeredUsers, forKey: registeredUserAPNSTokensKey)
    }
}

public protocol InfomaniakNotifiable {
    /// Register the user for remote notifications using the given token
    func registerUserForRemoteNotificationsIfNeeded(tokenData: Data, userApiFetcher: ApiFetcher) async
    /// After logging out manually remove the token for a given user
    func removeStoredToken(for userId: Int) async
}

public class InfomaniakNotifications: InfomaniakNotifiable {
    let userNotificationTokensStore = UserNotificationTokenStore()

    public init() {}

    func registerUserForRemoteNotificationsIfNeeded(apnsToken: String, userApiFetcher: ApiFetcher) async {
        guard let userId = userApiFetcher.currentToken?.userId else {
            return
        }

        let existingToken = await userNotificationTokensStore.apnsTokenForUser(id: userId)
        guard apnsToken != existingToken else {
            return
        }

        do {
            let success = try await userApiFetcher.registerForNotifications(registrationInfos: RegistrationInfos(token: apnsToken))
            if success {
                await userNotificationTokensStore.registerUser(id: userId, apnsToken: apnsToken)
            }
        } catch {
            // Fail silently, will be retried next time registerUserForRemoteNotificationsIfNeeded is called
        }
    }

    public func registerUserForRemoteNotificationsIfNeeded(tokenData: Data, userApiFetcher: ApiFetcher) async {
        let tokenParts = tokenData.map { data in String(format: "%02.2hhx", data) }
        let apnsToken = tokenParts.joined()

        await registerUserForRemoteNotificationsIfNeeded(apnsToken: apnsToken, userApiFetcher: userApiFetcher)
    }

    public func removeStoredToken(for userId: Int) async {
        await userNotificationTokensStore.removeToken(for: userId)
    }
}
