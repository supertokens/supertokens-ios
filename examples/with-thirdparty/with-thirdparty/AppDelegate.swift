//
//  AppDelegate.swift
//  with-thirdparty
//
//  Created by Nemi Shah on 10/11/23.
//

import UIKit
import SuperTokensIOS
import GoogleSignIn
import AppAuth

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var currentAuthorizationFlow: OIDExternalUserAgentSession?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        do {
            try SuperTokens.initialize(apiDomain: Constants.apiDomain)
        } catch {
            print("Failed to initialise SuperTokens: " +  error.localizedDescription)
        }
        
        URLProtocol.registerClass(SuperTokensURLProtocol.self)
        URLProtocol.registerClass(GithubLoginProtocol.self)
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func application(
      _ app: UIApplication,
      open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
      var handled: Bool

      handled = GIDSignIn.sharedInstance.handle(url)
      if handled {
        return true
      }
        
      if let authorizationFlow = self.currentAuthorizationFlow, authorizationFlow.resumeExternalUserAgentFlow(with: url) {
        self.currentAuthorizationFlow = nil
        return true
      }

      // Handle other custom URL types.

      // If not handled by this app, return false.
      return false
    }
}

