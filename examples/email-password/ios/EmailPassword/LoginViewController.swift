import UIKit
import SuperTokensIOS

final class LoginViewController: UIViewController {
    private let api = APIClient()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let statusLabel = UILabel()
    private let signInButton = UIButton(type: .system)
    private let signUpButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Email Password Login"
        view.backgroundColor = .systemBackground
        buildUI()

        if SuperTokens.doesSessionExist() {
            showSessionScreen()
        }
    }

    private func buildUI() {
        let titleLabel = UILabel()
        titleLabel.text = "Email/password auth"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.numberOfLines = 0

        let helpLabel = UILabel()
        helpLabel.text = "Create an account or sign in with an email and password. The backend uses SuperTokens Core at try.supertokens.com."
        helpLabel.font = .preferredFont(forTextStyle: .body)
        helpLabel.textColor = .secondaryLabel
        helpLabel.numberOfLines = 0

        emailField.borderStyle = .roundedRect
        emailField.placeholder = "you@example.com"
        emailField.textContentType = .emailAddress
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no

        passwordField.borderStyle = .roundedRect
        passwordField.placeholder = "password"
        passwordField.textContentType = .password
        passwordField.isSecureTextEntry = true

        signInButton.setTitle("Sign in", for: .normal)
        signInButton.addTarget(self, action: #selector(signIn), for: .touchUpInside)

        signUpButton.setTitle("Sign up", for: .normal)
        signUpButton.addTarget(self, action: #selector(signUp), for: .touchUpInside)

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.text = "Backend: \(ExampleConfig.apiDomain)\nCore: https://try.supertokens.com"

        let buttonStack = UIStackView(arrangedSubviews: [signInButton, signUpButton])
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12

        let stack = UIStackView(arrangedSubviews: [titleLabel, helpLabel, emailField, passwordField, buttonStack, statusLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
        ])
    }

    @objc private func signIn() {
        authenticate(action: "Signing in...") { email, password in
            try await self.api.signIn(email: email, password: password)
        }
    }

    @objc private func signUp() {
        authenticate(action: "Creating account...") { email, password in
            try await self.api.signUp(email: email, password: password)
        }
    }

    private func authenticate(action: String, request: @escaping (String, String) async throws -> AuthResponse) {
        let email = (emailField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordField.text ?? ""

        guard !email.isEmpty else {
            statusLabel.text = "Enter an email first."
            return
        }

        guard !password.isEmpty else {
            statusLabel.text = "Enter a password first."
            return
        }

        setLoading(true)
        statusLabel.text = action

        Task {
            do {
                _ = try await request(email, password)

                await MainActor.run {
                    setLoading(false)
                    showSessionScreen()
                }
            } catch {
                await MainActor.run {
                    statusLabel.text = "Auth failed: \(error.localizedDescription)"
                    setLoading(false)
                }
            }
        }
    }

    private func setLoading(_ isLoading: Bool) {
        signInButton.isEnabled = !isLoading
        signUpButton.isEnabled = !isLoading
    }

    private func showSessionScreen() {
        navigationController?.setViewControllers([SessionViewController()], animated: true)
    }
}
