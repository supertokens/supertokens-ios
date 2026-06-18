import Foundation
import Security

internal protocol TokenStorage {
    func get(_ name: String) -> String?
    func set(_ name: String, value: String) -> Bool
    func remove(_ name: String) -> Bool
}

internal class KeychainTokenStorage: TokenStorage {
    private let service: String
    private let accessGroup: String?

    init(service: String = "io.supertokens.session", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    func get(_ name: String) -> String? {
        var query = baseQuery(name)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func set(_ name: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }

        let query = baseQuery(name)
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if updateStatus == errSecSuccess {
            return true
        }

        if updateStatus != errSecItemNotFound {
            return false
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    func remove(_ name: String) -> Bool {
        let status = SecItemDelete(baseQuery(name) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(_ name: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

internal class SDKStorage {
    internal static let frontTokenKey = "supertokens-ios-fronttoken-key"
    internal static let antiCSRFKey = "supertokens-ios-anticsrf-key"
    private static let storageKeyPrefix = "st-storage-item-"
    private static var tokenStorage: TokenStorage = KeychainTokenStorage()

    internal static func configure(keychainAccessGroup: String?) {
        tokenStorage = KeychainTokenStorage(accessGroup: keychainAccessGroup)
    }

    internal static func setTokenStorageForTests(_ storage: TokenStorage) {
        tokenStorage = storage
    }

    internal static func genericKey(_ name: String) -> String {
        return "\(storageKeyPrefix)\(name)"
    }

    internal static func get(_ key: String) -> String? {
        if let value = tokenStorage.get(key) {
            return value
        }

        guard let legacyValue = Utils.getUserDefaults().string(forKey: key) else {
            return nil
        }

        if tokenStorage.set(key, value: legacyValue) {
            Utils.getUserDefaults().removeObject(forKey: key)
            Utils.getUserDefaults().synchronize()
            return legacyValue
        }

        return nil
    }

    internal static func set(_ key: String, value: String) -> Bool {
        if value.isEmpty {
            return remove(key)
        }

        guard tokenStorage.set(key, value: value) else {
            return false
        }

        Utils.getUserDefaults().removeObject(forKey: key)
        Utils.getUserDefaults().synchronize()
        return true
    }

    internal static func remove(_ key: String) -> Bool {
        let keychainRemoved = tokenStorage.remove(key)
        Utils.getUserDefaults().removeObject(forKey: key)
        Utils.getUserDefaults().synchronize()
        return keychainRemoved
    }

    internal static func clearSessionStorage() {
        for key in sessionKeys() {
            _ = remove(key)
        }

        FrontToken.clearInMemoryCache()
        AntiCSRF.clearInMemoryCache()
    }

    private static func sessionKeys() -> [String] {
        return [
            genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME),
            genericKey(SuperTokensConstants.REFRESH_TOKEN_NAME),
            genericKey(SuperTokensConstants.LAST_ACCESS_TOKEN_UPDATE),
            genericKey("sIRTFrontend"),
            frontTokenKey,
            antiCSRFKey
        ]
    }
}
