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

class EmptyRefreshTokenDelegate: RefreshTokenDelegate {
    func didUpdateToken(newToken: InfomaniakCore.ApiToken, oldToken: InfomaniakCore.ApiToken) {}

    func didFailRefreshToken(_ token: InfomaniakCore.ApiToken) {}
}

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @InjectService var login: InfomaniakLogin

    var body: some View {
        VStack {
            Button("Login & Register notifications") {
                login.asWebAuthenticationLoginFrom { result in
                    switch result {
                    case .success(let success):
                        login.getApiTokenUsing(code: success.code, codeVerifier: success.verifier) { token, _ in
                            guard let token else { return }
                            let apiFetcher = ApiFetcher()
                            apiFetcher.setToken(token, delegate: EmptyRefreshTokenDelegate())
                            DispatchQueue.main.async {
                                appDelegate.apiFetcher = apiFetcher

                                UIApplication.shared.registerForRemoteNotifications()
                            }
                        }
                    case .failure(let failure):
                        break
                    }
                }
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
