import Foundation

protocol SecretStoring {
    func string(for key: String) -> String?
    func setString(_ value: String?, for key: String)
}

final class InMemorySecretStore: SecretStoring {
    private var storage: [String: String] = [:]

    func string(for key: String) -> String? {
        storage[key]
    }

    func setString(_ value: String?, for key: String) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }
}
