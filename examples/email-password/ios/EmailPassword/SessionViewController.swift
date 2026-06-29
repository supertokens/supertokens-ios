import UIKit
import SuperTokensIOS

final class SessionViewController: UIViewController {
    private let api = APIClient()
    private let textView = UITextView()
    private let reloadButton = UIButton(type: .system)
    private let claimButton = UIButton(type: .system)
    private let refreshRetryButton = UIButton(type: .system)
    private let signOutButton = UIButton(type: .system)
    private var refreshRetryDebugText = "Refresh retry test: not run"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Session"
        view.backgroundColor = .systemBackground
        buildUI()
        reloadSessionInfo()
    }

    private func buildUI() {
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        reloadButton.setTitle("Reload session data", for: .normal)
        reloadButton.addTarget(self, action: #selector(reloadSessionInfo), for: .touchUpInside)

        claimButton.setTitle("Update access token payload", for: .normal)
        claimButton.addTarget(self, action: #selector(updateClaim), for: .touchUpInside)

        refreshRetryButton.setTitle("Test refresh retry", for: .normal)
        refreshRetryButton.addTarget(self, action: #selector(testRefreshRetry), for: .touchUpInside)

        signOutButton.setTitle("Sign out", for: .normal)
        signOutButton.addTarget(self, action: #selector(signOut), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [reloadButton, claimButton, refreshRetryButton, signOutButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 8

        let stack = UIStackView(arrangedSubviews: [textView, buttonStack])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 360),
        ])
    }

    @objc private func reloadSessionInfo() {
        setButtonsEnabled(false)
        textView.text = "Loading session data..."

        Task {
            do {
                let backendInfo = try await api.getSessionInfo()
                let localUserId = try? SuperTokens.getUserId()
                let localPayload = try? SuperTokens.getAccessTokenPayloadSecurely()
                let hasAccessToken = SuperTokens.getAccessToken() != nil
                let storageDebug = SessionStorageDebug.current()

                await MainActor.run {
                    textView.text = """
                    Local SDK
                    session exists: \(SuperTokens.doesSessionExist())
                    user id: \(localUserId ?? "<none>")
                    has access token: \(hasAccessToken)
                    access token payload: \(localPayload ?? [:])

                    \(storageDebug.description)

                    Protected backend response
                    status: \(backendInfo.status)
                    user id: \(backendInfo.userId)
                    session handle: \(backendInfo.sessionHandle)
                    access token payload: \(backendInfo.accessTokenPayload)

                    Refresh retry debug
                    \(refreshRetryDebugText)

                    SDK debug log
                    \(SuperTokensDebugLog.shared.snapshot())

                    Config
                    api domain: \(ExampleConfig.apiDomain)
                    api base path: \(ExampleConfig.apiBasePath)
                    core: https://try.supertokens.com
                    """
                    setButtonsEnabled(true)
                }
            } catch {
                await MainActor.run {
                    textView.text = "Could not load session data: \(error.localizedDescription)"
                    setButtonsEnabled(true)
                }
            }
        }
    }

    @objc private func updateClaim() {
        setButtonsEnabled(false)
        Task {
            do {
                try await api.setExampleClaim()
                await MainActor.run {
                    reloadSessionInfo()
                }
            } catch {
                await MainActor.run {
                    textView.text = "Could not update claim: \(error.localizedDescription)"
                    setButtonsEnabled(true)
                }
            }
        }
    }

    @objc private func testRefreshRetry() {
        setButtonsEnabled(false)
        textView.text = "Running refresh retry test..."
        SuperTokensDebugLog.shared.clear()

        Task {
            do {
                try await api.resetRefreshRetryDebug()
                let response = try await api.testRefreshRetry()

                await MainActor.run {
                    refreshRetryDebugText = """
                    final response status: \(response.status)
                    backend attempt: \(response.attempt)
                    message: \(response.message)
                    user id: \(response.userId)
                    session handle: \(response.sessionHandle)
                    access token payload: \(response.accessTokenPayload)
                    expected flow: first backend response 401, SDK refreshes via \(ExampleConfig.apiBasePath)/session/refresh, second backend response 200
                    """
                    reloadSessionInfo()
                }
            } catch {
                await MainActor.run {
                    refreshRetryDebugText = "Refresh retry test failed: \(error.localizedDescription)"
                    reloadSessionInfo()
                }
            }
        }
    }

    @objc private func signOut() {
        setButtonsEnabled(false)
        SuperTokens.signOut { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.textView.text = "Could not sign out: \(error.localizedDescription)"
                    self?.setButtonsEnabled(true)
                    return
                }

                self?.navigationController?.setViewControllers([LoginViewController()], animated: true)
            }
        }
    }

    private func setButtonsEnabled(_ isEnabled: Bool) {
        reloadButton.isEnabled = isEnabled
        claimButton.isEnabled = isEnabled
        refreshRetryButton.isEnabled = isEnabled
        signOutButton.isEnabled = isEnabled
    }
}
