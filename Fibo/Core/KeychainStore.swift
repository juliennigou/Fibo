import Foundation
import Security

struct StoredCredentials: Equatable {
    let email: String
    let password: String
}

enum KeychainError: LocalizedError {
    case status(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .status(status):
            (SecCopyErrorMessageString(status, nil) as String?) ?? "Erreur Keychain (\(status))."
        }
    }
}

struct KeychainStore {
    private let service = "com.juliennigou.Fibo"

#if targetEnvironment(simulator)
    // The simulator can be launched with an ad-hoc signature that has no
    // Keychain application identifier. Keep simulator credentials local to
    // the Mac so the real iPhone build can continue to use the secure Keychain.
    private let simulatorDefaults = UserDefaults.standard
    private let simulatorKeyPrefix = "fibo.simulator.keychain."
#endif

    func saveCredentials(email: String, password: String) throws {
        try set(email, account: "myfxbook.email")
        try set(password, account: "myfxbook.password")
    }

    func loadCredentials() -> StoredCredentials? {
        guard let email = get(account: "myfxbook.email"),
              let password = get(account: "myfxbook.password"),
              !email.isEmpty, !password.isEmpty else { return nil }
        return StoredCredentials(email: email, password: password)
    }

    func saveSession(_ session: String) throws {
        try set(session, account: "myfxbook.session")
    }

    func loadSession() -> String? {
        get(account: "myfxbook.session")
    }

    func clearSession() {
        delete(account: "myfxbook.session")
    }

    func clearAll() {
        delete(account: "myfxbook.email")
        delete(account: "myfxbook.password")
        delete(account: "myfxbook.session")
    }

    private func set(_ value: String, account: String) throws {
#if targetEnvironment(simulator)
        simulatorDefaults.set(value, forKey: simulatorKeyPrefix + account)
#else
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainError.status(updateStatus) }

        var insertion = query
        attributes.forEach { insertion[$0.key] = $0.value }
        let addStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.status(addStatus) }
#endif
    }

    private func get(account: String) -> String? {
#if targetEnvironment(simulator)
        simulatorDefaults.string(forKey: simulatorKeyPrefix + account)
#else
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
#endif
    }

    private func delete(account: String) {
#if targetEnvironment(simulator)
        simulatorDefaults.removeObject(forKey: simulatorKeyPrefix + account)
#else
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
#endif
    }
}
