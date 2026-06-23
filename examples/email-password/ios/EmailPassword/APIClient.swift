import Foundation
import SuperTokensIOS

enum APIClientError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from backend"
        case .backend(let message):
            return message
        }
    }
}

struct AuthResponse: Decodable {
    let status: String
    let user: AuthUser?
    let message: String?
}

struct AuthUser: Decodable {
    let id: String
    let emails: [String]?
}

struct ProtectedSessionInfo: Decodable {
    let status: String
    let userId: String
    let sessionHandle: String
    let accessTokenPayload: JSONValue
}

struct RefreshRetryDebugResponse: Decodable {
    let status: String
    let message: String
    let attempt: Int
    let userId: String
    let sessionHandle: String
    let accessTokenPayload: JSONValue
}

enum JSONValue: Decodable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw APIClientError.invalidResponse
        }
    }

    var description: String {
        switch self {
        case .string(let value):
            return "\"\(value)\""
        case .number(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .object(let value):
            return value
                .map { "\($0): \($1)" }
                .sorted()
                .joined(separator: ", ")
        case .array(let value):
            return value.map(\.description).joined(separator: ", ")
        case .null:
            return "null"
        }
    }
}

final class APIClient {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses?.insert(SuperTokensURLProtocol.self, at: 0)
        self.session = URLSession(configuration: configuration)
    }

    func signUp(email: String, password: String) async throws -> AuthResponse {
        return try await authenticate(path: "\(ExampleConfig.apiBasePath)/signup", email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> AuthResponse {
        return try await authenticate(path: "\(ExampleConfig.apiBasePath)/signin", email: email, password: password)
    }

    func getSessionInfo() async throws -> ProtectedSessionInfo {
        guard let url = URL(string: "\(ExampleConfig.apiDomain)/session") else {
            throw APIClientError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validate(response)
        return try decoder.decode(ProtectedSessionInfo.self, from: data)
    }

    func setExampleClaim() async throws {
        var request = try jsonRequest(path: "/session/custom-claim", method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["value": "updated-from-ios"])

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    func resetRefreshRetryDebug() async throws {
        var request = try jsonRequest(path: "/debug/refresh-once/reset", method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: [:])

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    func testRefreshRetry() async throws -> RefreshRetryDebugResponse {
        guard let url = URL(string: "\(ExampleConfig.apiDomain)/debug/refresh-once") else {
            throw APIClientError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validate(response)
        return try decoder.decode(RefreshRetryDebugResponse.self, from: data)
    }

    private func jsonRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: "\(ExampleConfig.apiDomain)\(path)") else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        return request
    }

    private func authenticate(path: String, email: String, password: String) async throws -> AuthResponse {
        var request = try jsonRequest(path: path, method: "POST")
        request.addValue("emailpassword", forHTTPHeaderField: "rid")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "formFields": [
                    ["id": "email", "value": email],
                    ["id": "password", "value": password],
                ],
            ]
        )

        let (data, response) = try await session.data(for: request)
        try validate(response)

        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        if authResponse.status != "OK" {
            throw APIClientError.backend(authResponse.message ?? authResponse.status)
        }

        return authResponse
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if httpResponse.statusCode >= 300 {
            throw APIClientError.backend("Backend returned HTTP \(httpResponse.statusCode)")
        }
    }
}
