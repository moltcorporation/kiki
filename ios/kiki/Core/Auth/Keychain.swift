import Foundation
import Security

/// Minimal Keychain wrapper for the session token and user ID.
enum Keychain {
    private static let service = "com.moltcorporation.kiki.auth"

    static var sessionToken: String? {
        get { read("sessionToken") }
        set { write("sessionToken", newValue) }
    }

    static var userID: String? {
        get { read("userID") }
        set { write("userID", newValue) }
    }

    static func clear() {
        sessionToken = nil
        userID = nil
    }

    private static func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    private static func read(_ key: String) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ key: String, _ value: String?) {
        SecItemDelete(query(key) as CFDictionary)
        guard let value else { return }
        var q = query(key)
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }
}
