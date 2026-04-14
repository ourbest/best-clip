import Foundation
import Security

final class KeychainSecretStore: SecretStoring {
    private let service: String
    private let accessGroup: String?

    init(service: String = "com.autoalbum.autoclips", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    func string(for key: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    func setString(_ value: String?, for key: String) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        if let value {
            let data = Data(value.utf8)
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]

            if let accessGroup {
                var extendedAttributes = attributes
                extendedAttributes[kSecAttrAccessGroup as String] = accessGroup
                let status = SecItemUpdate(baseQuery as CFDictionary, extendedAttributes as CFDictionary)
                if status == errSecItemNotFound {
                    var addQuery = baseQuery
                    addQuery[kSecValueData as String] = data
                    addQuery[kSecAttrAccessGroup as String] = accessGroup
                    _ = SecItemAdd(addQuery as CFDictionary, nil)
                }
                return
            }

            let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            if status == errSecItemNotFound {
                var addQuery = baseQuery
                addQuery[kSecValueData as String] = data
                _ = SecItemAdd(addQuery as CFDictionary, nil)
            }
            return
        }

        _ = SecItemDelete(baseQuery as CFDictionary)
    }
}
