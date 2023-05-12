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

actor UserSubscriptionStore {
    private let registeredUsersKey = "registeredUsers"
    private let jsonEncoder = JSONEncoder()
    private let userDefaults: UserDefaults
    var registeredUsers = [String: Subscription]()

    init(appGroup: String?) {
        if let appGroup,
            let appGroupDefaults = UserDefaults(suiteName: appGroup) {
            userDefaults = appGroupDefaults
        } else {
            userDefaults = UserDefaults.standard
        }
        guard let registeredUsersData = userDefaults.dictionary(forKey: registeredUsersKey) as? [String: Data]
        else { return }
        let jsonDecoder = JSONDecoder()

        for registeredUserData in registeredUsersData {
            if let registeredUser = try? jsonDecoder.decode(Subscription.self, from: registeredUserData.value) {
                registeredUsers[registeredUserData.key] = registeredUser
            }
        }
    }

    func saveRegisteredUsers() {
        var rawRegisteredUsers = [String: Data]()
        for registeredUser in registeredUsers {
            rawRegisteredUsers[registeredUser.key] = try? jsonEncoder.encode(registeredUser.value)
        }
        userDefaults.set(rawRegisteredUsers, forKey: registeredUsersKey)
    }

    func saveSubscriptionForUser(id: Int, subscription: Subscription) {
        registeredUsers["\(id)"] = subscription
        saveRegisteredUsers()
    }

    func subscriptionForUser(id: Int) -> Subscription? {
        return registeredUsers["\(id)"]
    }

    func removeSubscription(for userId: Int) {
        registeredUsers["\(userId)"] = nil
        saveRegisteredUsers()
    }
}

public protocol InfomaniakNotifiable {
    /// Get the current Subscription for a given user
    func subscriptionForUser(id: Int) async -> Subscription?
    /// Register topics for a user
    func updateTopicsIfNeeded(_ topics: [String], userApiFetcher: ApiFetcher) async
    /// Register the user for remote notifications using the given token
    func updateRemoteNotificationsTokenIfNeeded(tokenData: Data, userApiFetcher: ApiFetcher) async
    /// After logging out manually remove the token for a given user
    func removeStoredTokenFor(userId: Int) async
}

public class InfomaniakNotifications: InfomaniakNotifiable {
    let userSubscriptionsStore: UserSubscriptionStore

    public init(appGroup: String? = nil) {
        self.userSubscriptionsStore = UserSubscriptionStore(appGroup: appGroup)
    }

    func registerAndSave(newSubscription: Subscription, userApiFetcher: ApiFetcher) async {
        guard let userId = userApiFetcher.currentToken?.userId else {
            return
        }

        guard !newSubscription.token.isEmpty else {
            // We will send topics when we get an APNS token
            await userSubscriptionsStore.saveSubscriptionForUser(id: userId, subscription: newSubscription)
            return
        }

        do {
            let success = try await userApiFetcher
                .registerForNotifications(registrationInfos: RegistrationInfos(token: newSubscription.token,
                                                                               topics: newSubscription.topics))
            if success {
                await userSubscriptionsStore.saveSubscriptionForUser(id: userId, subscription: newSubscription)
            }
        } catch {
            // Fail silently, will be retried next time registerAndSave is called
        }
    }

    public func subscriptionForUser(id: Int) async -> Subscription? {
        return await userSubscriptionsStore.subscriptionForUser(id: id)
    }

    public func updateTopicsIfNeeded(_ topics: [String], userApiFetcher: ApiFetcher) async {
        guard let userId = userApiFetcher.currentToken?.userId else {
            return
        }

        let existingSubscription = await userSubscriptionsStore.subscriptionForUser(id: userId)
        guard existingSubscription?.topics != topics else { return }

        let newSubscription = Subscription(token: existingSubscription?.token ?? "", topics: topics)
        await registerAndSave(newSubscription: newSubscription, userApiFetcher: userApiFetcher)
    }

    public func updateRemoteNotificationsTokenIfNeeded(tokenData: Data, userApiFetcher: ApiFetcher) async {
        guard let userId = userApiFetcher.currentToken?.userId else {
            return
        }

        let tokenParts = tokenData.map { data in String(format: "%02.2hhx", data) }
        let apnsToken = tokenParts.joined()

        let existingSubscription = await userSubscriptionsStore.subscriptionForUser(id: userId)
        guard existingSubscription?.token != apnsToken else { return }

        let newSubscription = Subscription(token: apnsToken, topics: existingSubscription?.topics ?? [])
        await registerAndSave(newSubscription: newSubscription, userApiFetcher: userApiFetcher)
    }

    public func removeStoredTokenFor(userId: Int) async {
        await userSubscriptionsStore.removeSubscription(for: userId)
    }
}
