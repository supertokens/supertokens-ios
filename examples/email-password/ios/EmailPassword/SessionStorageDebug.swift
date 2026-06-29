import Foundation
import Security
import SuperTokensIOS

struct SessionStorageDebug {
    struct Item {
        let label: String
        let keychainAccount: String
        let existsInKeychain: Bool
        let existsInUserDefaults: Bool
    }

    let keychainService: String
    let keychainAccessGroup: String?
    let keychainProbeSucceeded: Bool
    let items: [Item]

    var description: String {
        let itemLines = items.map { item in
            "\(item.label): keychain=\(item.existsInKeychain ? "present" : "missing"), legacy UserDefaults=\(item.existsInUserDefaults ? "present" : "missing")"
        }

        return ([
            "Token storage debug",
            "active storage: Keychain",
            "keychain service: \(keychainService)",
            "keychain access group: \(keychainAccessGroup ?? "<none>")",
            "keychain write probe: \(keychainProbeSucceeded ? "passed" : "failed")",
            "token values: redacted",
        ] + itemLines).joined(separator: "\n")
    }

    static func current() -> SessionStorageDebug {
        let service = "io.supertokens.session.\(ExampleConfig.apiDomain)\(ExampleConfig.apiBasePath)"
        let keys = [
            ("access token", "st-storage-item-st-access-token"),
            ("refresh token", "st-storage-item-st-refresh-token"),
            ("front token", "supertokens-ios-fronttoken-key"),
            ("anti-csrf", "supertokens-ios-anticsrf-key"),
            ("last access token update", "st-storage-item-st-last-access-token-update"),
            ("refresh retry metadata", "st-storage-item-sIRTFrontend"),
        ]

        return SessionStorageDebug(
            keychainService: service,
            keychainAccessGroup: nil,
            keychainProbeSucceeded: canWriteToKeychain(service: service),
            items: keys.map { label, account in
                Item(
                    label: label,
                    keychainAccount: account,
                    existsInKeychain: keychainContains(service: service, account: account),
                    existsInUserDefaults: UserDefaults.standard.string(forKey: account) != nil
                )
            }
        )
    }

    private static func keychainContains(service: String, account: String) -> Bool {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    private static func canWriteToKeychain(service: String) -> Bool {
        let account = "email-password-example-keychain-probe"
        let value = Data("probe".utf8)
        let query = baseQuery(service: service, account: account)
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = value
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let added = SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        let removed = SecItemDelete(query as CFDictionary) == errSecSuccess
        return added && removed
    }

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
