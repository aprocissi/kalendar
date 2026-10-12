// Secrets live in the Keychain, never UserDefaults. Kalendar stores one item per Google account:
// that account's OAuth refresh token. Items are device-only (no iCloud sync), so no entitlement or
// provisioning profile is needed.
import Foundation
import Security

public enum Keychain {
    private static let service = "com.massena.kalendar"

    private static func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// Stores `value`, or deletes the item when `value` is nil or empty.
    @discardableResult
    public static func set(_ value: String?, for account: String) -> Bool {
        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else {
            let status = SecItemDelete(query(account) as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }
        // Update in place rather than delete-then-add, so a failed add never loses the old token.
        let update = [kSecValueData as String: data] as CFDictionary
        var status = SecItemUpdate(query(account) as CFDictionary, update)
        if status == errSecItemNotFound {
            var add = query(account)
            add[kSecValueData as String] = data
            // AfterFirstUnlock: sync runs in the background, including while the screen is locked.
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        }
        if status != errSecSuccess { Log.auth.error("keychain write failed for \(account): \(status)") }
        return status == errSecSuccess
    }

    public static func get(_ account: String) -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
