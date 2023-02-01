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
import InfomaniakLogin
import InfomaniakNotifications
import SwiftUI

@main
struct InfomaniakNotificationsSampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let mailClientId = "E90BC22D-67A8-452C-BE93-28DA33588CA4"
        let mailRedirectUri = "com.infomaniak.mail://oauth2redirect"
        let loginFactory = Factory(type: InfomaniakLogin.self) { _, _ in
            InfomaniakLogin(clientId: mailClientId, redirectUri: mailRedirectUri)
        }

        let networkLogin = Factory(type: InfomaniakNetworkLogin.self) { _, _ in
            InfomaniakNetworkLogin(clientId: mailClientId, redirectUri: mailRedirectUri)
        }

        let notificationFactory = Factory(type: InfomaniakNotifications.self) { _, _ in
            InfomaniakNotifications()
        }

        do {
            try SimpleResolver.sharedResolver.store(factory: loginFactory)
            try SimpleResolver.sharedResolver.store(factory: networkLogin)
            try SimpleResolver.sharedResolver.store(factory: notificationFactory)
        }
        catch {
            fatalError("unexpected DI error \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    var apiFetcher: ApiFetcher?
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard let apiFetcher else { return }
        let notificationsService = InjectService<InfomaniakNotifications>().wrappedValue
        Task {
            await notificationsService.registerUserForRemoteNotificationsIfNeeded(tokenData: deviceToken, userApiFetcher: apiFetcher)
        }
    }
}
