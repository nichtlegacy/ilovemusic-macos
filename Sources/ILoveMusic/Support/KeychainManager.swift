import Foundation
import Security

/// A simple helper to store strings securely in the macOS Keychain.
enum KeychainManager {
  static func save(_ value: String, for account: String) {
    guard let data = value.data(using: .utf8) else { return }

    let query = query(service: AppIdentity.keychainService, account: account)

    let attributesToUpdate: [String: Any] = [
      kSecValueData as String: data
    ]

    let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
    if status == errSecItemNotFound {
      var newQuery = query
      newQuery[kSecValueData as String] = data
      SecItemAdd(newQuery as CFDictionary, nil)
    }
  }

  static func load(for account: String) -> String? {
    var item: CFTypeRef?
    let status = SecItemCopyMatching(
      query(service: AppIdentity.keychainService, account: account, returnData: true) as CFDictionary,
      &item
    )
    guard status == errSecSuccess else { return nil }
    if let data = item as? Data,
       let value = String(data: data, encoding: .utf8) {
      return value
    }
    return nil
  }

  static func delete(for account: String) {
    SecItemDelete(query(service: AppIdentity.keychainService, account: account) as CFDictionary)
  }

  private static func query(
    service: String,
    account: String,
    returnData: Bool = false
  ) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: account,
      kSecAttrService as String: service
    ]
    if returnData {
      query[kSecReturnData as String] = true
      query[kSecMatchLimit as String] = kSecMatchLimitOne
    }
    return query
  }
}
