//
//  LoginScreenViewController.swift
//  with-thirdparty
//
//  Created by Nemi Shah on 10/11/23.
//

import UIKit
import GoogleSignIn
import AppAuth

class LoginScreenViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func onGoogleCliked() {
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { signInResult, error in
            guard error == nil else { return }

            guard let authCode: String = signInResult?.serverAuthCode as? String else {
                print("Google login did not return an authorisation code")
                return
            }
            
            let url = URL(string: Constants.apiDomain + "/auth/signinup")
            var request = URLRequest(url: url!)
            request.httpMethod = "POST"
            
            let data = try! JSONSerialization.data(withJSONObject: [
                "thirdPartyId": "google",
                "redirectURIInfo": [
                    // For native flows we do not have a redirect uri
                    "redirectURIOnProviderDashboard": "",
                    "redirectURIQueryParams": [
                        "code": authCode
                    ],
                ],
            ])
            request.httpBody = data
            request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
            
            URLSession.shared.dataTask(with: request) {
                data, response, error in
                
                if error != nil {
                    print("Google login failed: \(error!.localizedDescription)")
                }
                
                if let _response: URLResponse = response, let httpResponse: HTTPURLResponse = _response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        DispatchQueue.main.async { [weak self] in
                            self?.navigationController?.pushViewController(HomeScreenViewController(nibName: "HomeView", bundle: nil), animated: true)
                        }
                    } else {
                        print("SuperTokens API failed with code: \(httpResponse.statusCode)")
                    }
                }
            }.resume()
        }
    }
    
    @IBAction func onGithubClicked() {
        let authorizationEndpoint = URL(string: "https://github.com/login/oauth/authorize")!
        let tokenEndpoint = URL(string: "https://github.com/login/oauth/access_token")!
        let configuration = OIDServiceConfiguration(authorizationEndpoint: authorizationEndpoint, tokenEndpoint: tokenEndpoint)
        
        let request = OIDAuthorizationRequest.init(configuration: configuration,
          clientId: "GITHUB_CLIENT_ID",
          scopes: ["user"],
          redirectURL: URL(string: "com.supertokens.supertokensexample://oauthredirect")!,
          responseType: OIDResponseTypeCode,
          additionalParameters: nil)

        // performs authentication request
        print("Initiating authorization request with scope: \(request.scope ?? "nil")")

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        appDelegate.currentAuthorizationFlow = OIDAuthorizationService.present(request, presenting: self, callback: {
            response, error in
            
            if let response = response, let authCode: String = response.authorizationCode {
                let url = URL(string: Constants.apiDomain + "/auth/signinup")
                var request = URLRequest(url: url!)
                request.httpMethod = "POST"
                
                let data = try! JSONSerialization.data(withJSONObject: [
                    "thirdPartyId": "github",
                    "redirectURIInfo": [
                        // For native flows we do not have a redirect uri
                        "redirectURIOnProviderDashboard": "com.supertokens.supertokensexample://oauthredirect",
                        "redirectURIQueryParams": [
                            "code": authCode
                        ],
                    ],
                ])
                request.httpBody = data
                request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
                
                URLSession.shared.dataTask(with: request) {
                    data, response, error in
                    
                    if error != nil {
                        print("Github login failed: \(error!.localizedDescription)")
                    }
                    
                    if let _response: URLResponse = response, let httpResponse: HTTPURLResponse = _response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            DispatchQueue.main.async { [weak self] in
                                self?.navigationController?.pushViewController(HomeScreenViewController(nibName: "HomeView", bundle: nil), animated: true)
                            }
                        } else {
                            print("SuperTokens API failed with code: \(httpResponse.statusCode)")
                        }
                    }
                }.resume()
            } else {
                print("Github login failed")
            }
        })
    }
}
