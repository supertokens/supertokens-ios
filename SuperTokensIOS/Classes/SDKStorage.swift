import Foundation
import Security

internal protocol TokenStorage {
    func get(_ name: String) -> String?
    func set(_ name: String, value: String) -> Bool
    func remove(_ name: String) -> Bool
}

internal protocol KeychainClient {
    func get(_ query: [String: Any]) -> (status: OSStatus, data: Data?)
    func set(_ query: [String: Any]) -> OSStatus
    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus
    func remove(_ query: [String: Any]) -> OSStatus
}

internal class SystemKeychainClient: KeychainClient {
    func get(_ query: [String: Any]) -> (status: OSStatus, data: Data?) {
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }

    func set(_ query: [String: Any]) -> OSStatus {
        return SecItemAdd(query as CFDictionary, nil)
    }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        return SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    func remove(_ query: [String: Any]) -> OSStatus {
        return SecItemDelete(query as CFDictionary)
    }
}

internal class KeychainTokenStorage: TokenStorage {
    private let service: String
    private let accessGroup: String?
    private let keychain: KeychainClient
    private(set) var lastErrorStatus: OSStatus?

    init(service: String = "io.supertokens.session", accessGroup: String? = nil, keychain: KeychainClient = SystemKeychainClient()) {
        self.service = service
        self.accessGroup = accessGroup
        self.keychain = keychain
    }

    func get(_ name: String) -> String? {
        var query = baseQuery(name)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let result = keychain.get(query)
        guard result.status == errSecSuccess, let data = result.data else {
            recordErrorStatus(result.status)
            return nil
        }

        lastErrorStatus = nil
        return String(data: data, encoding: .utf8)
    }

    func set(_ name: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }

        let query = baseQuery(name)
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = keychain.update(query, attributes: update)

        if updateStatus == errSecSuccess {
            lastErrorStatus = nil
            return true
        }

        if updateStatus != errSecItemNotFound {
            recordErrorStatus(updateStatus)
            return false
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = keychain.set(addQuery)
        if addStatus == errSecSuccess {
            lastErrorStatus = nil
            return true
        }

        if addStatus == errSecDuplicateItem {
            let retryStatus = keychain.update(query, attributes: update)
            if retryStatus == errSecSuccess {
                lastErrorStatus = nil
                return true
            }

            recordErrorStatus(retryStatus)
            return false
        }

        recordErrorStatus(addStatus)
        return false
    }

    func remove(_ name: String) -> Bool {
        let status = keychain.remove(baseQuery(name))
        let didRemove = status == errSecSuccess || status == errSecItemNotFound
        if didRemove {
            lastErrorStatus = nil
        } else {
            recordErrorStatus(status)
        }

        return didRemove
    }

    func canStoreTokens() -> Bool {
        let probeKey = "__supertokens_keychain_probe_\(UUID().uuidString)"
        guard set(probeKey, value: "probe") else {
            return false
        }

        return remove(probeKey)
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

    private func recordErrorStatus(_ status: OSStatus) {
        if status != errSecItemNotFound {
            lastErrorStatus = status
            print("SuperTokens: Keychain operation failed with OSStatus \(status)")
        }
    }
}

internal class SDKStorage {
    internal static let frontTokenKey = "supertokens-ios-fronttoken-key"
    internal static let antiCSRFKey = "supertokens-ios-anticsrf-key"
    private static let defaultKeychainService = "io.supertokens.session"
    private static let storageKeyPrefix = "st-storage-item-"
    private static var tokenStorage: TokenStorage = KeychainTokenStorage()

    @discardableResult
    internal static func configure(userDefaultsSuiteName: String?, keychainAccessGroup: String?, apiDomain: String? = nil, apiBasePath: String? = nil) -> Bool {
        // userDefaultsSuiteName is only for legacy UserDefaults migration; active sharing uses keychainAccessGroup.
        let keychainStorage = KeychainTokenStorage(
            service: keychainService(apiDomain: apiDomain, apiBasePath: apiBasePath),
            accessGroup: keychainAccessGroup
        )
        tokenStorage = keychainStorage

        if keychainAccessGroup != nil {
            return keychainStorage.canStoreTokens()
        }

        return true
    }

    internal static func setTokenStorageForTests(_ storage: TokenStorage) {
        tokenStorage = storage
    }

    internal static func genericKey(_ name: String) -> String {
        return "\(storageKeyPrefix)\(name)"
    }

    internal static func keychainService(apiDomain: String?, apiBasePath: String?) -> String {
        guard let apiDomain = apiDomain, let apiBasePath = apiBasePath else {
            return defaultKeychainService
        }

        return "\(defaultKeychainService).\(apiDomain)\(apiBasePath)"
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

    @discardableResult
    internal static func clearSessionStorage() -> Bool {
        var didClear = true

        for key in sessionKeys() {
            didClear = remove(key) && didClear
        }

        if didClear {
            FrontToken.clearInMemoryCache()
            AntiCSRF.clearInMemoryCache()
        }

        return didClear
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
