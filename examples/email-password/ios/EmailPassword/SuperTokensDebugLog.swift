import Foundation
import SuperTokensIOS

final class SuperTokensDebugLog {
    static let shared = SuperTokensDebugLog()

    private let queue = DispatchQueue(label: "io.supertokens.example.debug-log")
    private var entries: [String] = []

    private init() {}

    func clear() {
        queue.sync {
            entries.removeAll()
        }
    }

    func record(_ message: String) {
        queue.sync {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            entries.append("\(timestamp) \(message)")
            if entries.count > 20 {
                entries.removeFirst(entries.count - 20)
            }
        }
    }

    func record(event: EventType) {
        record("event=\(name(for: event))")
    }

    func snapshot() -> String {
        queue.sync {
            if entries.isEmpty {
                return "<none>"
            }

            return entries.joined(separator: "\n")
        }
    }

    private func name(for event: EventType) -> String {
        switch event {
        case .SIGN_OUT:
            return "SIGN_OUT"
        case .REFRESH_SESSION:
            return "REFRESH_SESSION"
        case .SESSION_CREATED:
            return "SESSION_CREATED"
        case .ACCESS_TOKEN_PAYLOAD_UPDATED:
            return "ACCESS_TOKEN_PAYLOAD_UPDATED"
        case .UNAUTHORISED:
            return "UNAUTHORISED"
        }
    }
}
