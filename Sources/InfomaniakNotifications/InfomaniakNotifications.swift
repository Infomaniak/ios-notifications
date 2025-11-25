//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation
import InfomaniakCore
import InfomaniakDI

public extension Endpoint {
    static var registerDevice: Endpoint {
        return .baseV1.appending(path: "/devices/register")
    }
}

extension ApiFetcher {
    func registerForNotifications(registrationInfos: RegistrationInfos) async throws -> Bool {
        try await perform(request: authenticatedRequest(.registerDevice, method: .post, parameters: registrationInfos))
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
    func updateTopicsIfNeeded(_ topics: [Topic], userApiFetcher: ApiFetcher) async
    /// Register the user for remote notifications using the given token
    func updateRemoteNotificationsToken(tokenData: Data, userApiFetcher: ApiFetcher, updatePolicy: TokenUpdatePolicy) async
    /// After logging out manually remove the token for a given user
    func removeStoredTokenFor(userId: Int) async
}

public enum TokenUpdatePolicy {
    /// Always send the token and topics to the server
    case always
    /// Send the token and topics to the server only if they were modified
    case ifModified
}

public struct InfomaniakNotifications: Sendable, InfomaniakNotifiable {
    let userSubscriptionsStore: UserSubscriptionStore

    public init(appGroup: String? = nil) {
        userSubscriptionsStore = UserSubscriptionStore(appGroup: appGroup)
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
            let registrationInfos = await RegistrationInfos(token: newSubscription.token, topics: newSubscription.topics)
            let success = try await userApiFetcher.registerForNotifications(registrationInfos: registrationInfos)
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

    public func updateTopicsIfNeeded(_ topics: [Topic], userApiFetcher: ApiFetcher) async {
        guard let userId = userApiFetcher.currentToken?.userId else {
            return
        }

        let newUniqueTopics = Array(Set(topics))

        let existingSubscription = await userSubscriptionsStore.subscriptionForUser(id: userId)

        guard !(existingSubscription?.topics ?? []).isEqualToTopics(newUniqueTopics) else { return }

        let newSubscription = Subscription(token: existingSubscription?.token ?? "", topics: newUniqueTopics)
        await registerAndSave(newSubscription: newSubscription, userApiFetcher: userApiFetcher)
    }

    public func updateRemoteNotificationsToken(
        tokenData: Data,
        userApiFetcher: ApiFetcher,
        updatePolicy: TokenUpdatePolicy
    ) async {
        guard let userId = userApiFetcher.currentToken?.userId else {
            return
        }

        let tokenParts = tokenData.map { data in String(format: "%02.2hhx", data) }
        let apnsToken = tokenParts.joined()

        let existingSubscription = await userSubscriptionsStore.subscriptionForUser(id: userId)

        if updatePolicy == .ifModified && existingSubscription?.token == apnsToken { return }

        let newSubscription = Subscription(token: apnsToken, topics: existingSubscription?.topics ?? [])
        await registerAndSave(newSubscription: newSubscription, userApiFetcher: userApiFetcher)
    }

    public func removeStoredTokenFor(userId: Int) async {
        await userSubscriptionsStore.removeSubscription(for: userId)
    }
}
