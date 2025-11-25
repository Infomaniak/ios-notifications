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

import InfomaniakCore
import InfomaniakDI
import InfomaniakLogin
@testable import InfomaniakNotifications
import XCTest

class FakeTokenDelegate: RefreshTokenDelegate {
    func didUpdateToken(newToken: ApiToken, oldToken: ApiToken) {}

    func didFailRefreshToken(_ token: ApiToken) {}
}

final class InfomaniakNotificationsTests: XCTestCase {
    private static let token = ApiToken(accessToken: Env.token,
                                        expiresIn: Int.max,
                                        refreshToken: "",
                                        scope: "",
                                        tokenType: "",
                                        userId: Env.userId,
                                        expirationDate: Date(timeIntervalSinceNow: TimeInterval(Int.max)))

    private var apiFetcher: ApiFetcher!
    private static let fakeAPNSToken = "aabbcc"
    private static let fakeAPNSTokenData = fakeAPNSToken.data(using: .utf8)!

    override class func setUp() {
        let factory = Factory(type: InfomaniakNetworkLogin.self) { _, _ in
            // We don't need InfomaniakNetworkLogin but it is injected in the ApiFetcher
            InfomaniakNetworkLogin(config: .init(clientId: ""))
        }
        SimpleResolver.sharedResolver.store(factory: factory)
    }

    override func setUp() {
        apiFetcher = ApiFetcher()
        apiFetcher.setToken(InfomaniakNotificationsTests.token, delegate: FakeTokenDelegate())
    }

    func testApiRegistration() async throws {
        let registrationInfos = await RegistrationInfos(token: InfomaniakNotificationsTests.fakeAPNSToken, topics: ["test1"])
        let registrationResult = try await apiFetcher.registerForNotifications(registrationInfos: registrationInfos)
        XCTAssertTrue(registrationResult, "Registration shouldn't fail")
    }

    func testRegisterDeviceTokenIfNeeded() async throws {
        let notificationsService = InfomaniakNotifications()
        await notificationsService.updateRemoteNotificationsToken(
            tokenData: InfomaniakNotificationsTests.fakeAPNSTokenData,
            userApiFetcher: apiFetcher,
            updatePolicy: .ifModified
        )
        let registeredToken = await notificationsService.userSubscriptionsStore
            .subscriptionForUser(id: apiFetcher.currentToken!.userId)
        XCTAssertNotNil(registeredToken, "Registered token shouldn't be nil")
    }

    func testUpdateTopics() async throws {
        let notificationsService = InfomaniakNotifications()
        let testTopics: [Topic] = ["topic1", "topic2"]
        await notificationsService.removeStoredTokenFor(userId: apiFetcher.currentToken!.userId)

        await notificationsService.updateTopicsIfNeeded(testTopics, userApiFetcher: apiFetcher)
        let storedSubscription = await notificationsService.userSubscriptionsStore
            .subscriptionForUser(id: apiFetcher.currentToken!.userId)
        XCTAssertNotNil(storedSubscription, "Stored subscription shouldn't be null")
        XCTAssertEqual(storedSubscription?.topics, testTopics, "Stored topics are not matching")
        XCTAssertTrue(storedSubscription?.token.isEmpty == true, "Stored token should be empty")
        await notificationsService.updateRemoteNotificationsToken(
            tokenData: InfomaniakNotificationsTests.fakeAPNSTokenData,
            userApiFetcher: apiFetcher,
            updatePolicy: .ifModified
        )
        let storedSubscriptionWithToken = await notificationsService.userSubscriptionsStore
            .subscriptionForUser(id: apiFetcher.currentToken!.userId)
        XCTAssertNotNil(storedSubscriptionWithToken, "Stored subscription shouldn't be null")
        XCTAssertEqual(storedSubscriptionWithToken?.topics, testTopics, "Stored topics are not matching")
        XCTAssertTrue(storedSubscriptionWithToken?.token.isEmpty == false, "Stored token shouldn't be nil")
    }
}
