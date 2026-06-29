import UIKit
import SuperTokensIOS

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        URLProtocol.registerClass(SuperTokensURLProtocol.self)

        do {
            try SuperTokens.initialize(
                apiDomain: ExampleConfig.apiDomain,
                apiBasePath: ExampleConfig.apiBasePath,
                eventHandler: { event in
                    SuperTokensDebugLog.shared.record(event: event)
                    print("SuperTokens event: \(event)")
                },
                preAPIHook: { action, request in
                    if action == .REFRESH_SESSION {
                        SuperTokensDebugLog.shared.record("refresh preAPIHook url=\(request.url?.absoluteString ?? "<none>")")
                    }

                    return request
                },
                postAPIHook: { action, _request, response in
                    if action == .REFRESH_SESSION {
                        let status = (response as? HTTPURLResponse)?.statusCode.description ?? "<none>"
                        SuperTokensDebugLog.shared.record("refresh postAPIHook status=\(status)")
                    }
                }
            )
        } catch {
            assertionFailure("Failed to initialize SuperTokens: \(error)")
        }

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
