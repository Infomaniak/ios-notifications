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
