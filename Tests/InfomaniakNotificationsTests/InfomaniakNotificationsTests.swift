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

import InfomaniakCore
import InfomaniakDI

import XCTest

@testable import InfomaniakNotifications

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

    override class func setUp() {
        let factory = Factory(type: InfomaniakNetworkLogin.self) { _, _ in
            // We don't need InfomaniakNetworkLogin but it is injected in the ApiFetcher
            InfomaniakNetworkLogin(clientId: "")
        }
        try! SimpleResolver.sharedResolver.store(factory: factory)
    }

    override func setUp() {
        apiFetcher = ApiFetcher()
        apiFetcher.setToken(InfomaniakNotificationsTests.token, delegate: FakeTokenDelegate())
    }

    func testApiRegistration() async throws {
        let registrationInfos = RegistrationInfos(token: InfomaniakNotificationsTests.fakeAPNSToken)
        let registrationResult = try await apiFetcher.registerForNotifications(registrationInfos: registrationInfos)
        XCTAssertTrue(registrationResult, "Registration shouldn't fail")
    }

    func testRegisterDeviceToken() async throws {
        let notificationsService = InfomaniakNotification()
        await notificationsService.registerUserForRemoteNotificationsIfNeeded(apnsToken: InfomaniakNotificationsTests.fakeAPNSToken,
                                                                              userApiFetcher: apiFetcher)
        let registeredToken = await notificationsService.userNotificationTokensStore
            .apnsTokenForUser(id: apiFetcher.currentToken!.userId)
        XCTAssertNotNil(registeredToken, "Registered token shouldn't be nil")
    }
}
