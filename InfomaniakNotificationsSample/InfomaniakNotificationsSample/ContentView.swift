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
