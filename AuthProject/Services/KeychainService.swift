import Foundation
import Security
import CryptoKit

class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    // MARK: - Encryption Key Management
    
    func saveEncryptionKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        try saveData(keyData, for: "ENCRYPTION_KEY", service: "AuthProject")
    }
    
    func loadEncryptionKey() throws -> SymmetricKey {
        let keyData = try loadData(for: "ENCRYPTION_KEY", service: "AuthProject")
        return SymmetricKey(data: keyData)
    }
    
    // MARK: - OAuth Credentials Storage
    
    func saveOAuthCredentials(_ credentials: OAuthCredentials, for serviceName: String) throws {
        let credentialData = try JSONEncoder().encode(credentials)
        try saveData(credentialData, for: "oauth_\(serviceName)", service: "AuthProject")
    }
    
    func loadOAuthCredentials(for serviceName: String) throws -> OAuthCredentials {
        let credentialData = try loadData(for: "oauth_\(serviceName)", service: "AuthProject")
        return try JSONDecoder().decode(OAuthCredentials.self, from: credentialData)
    }
    
    func deleteOAuthCredentials(for serviceName: String) throws {
        try deleteData(for: "oauth_\(serviceName)", service: "AuthProject")
    }
    
    // MARK: - API Key Storage
    
    func saveAPIKey(_ apiKey: String, for serviceName: String) throws {
        let apiKeyData = apiKey.data(using: .utf8)!
        try saveData(apiKeyData, for: "apikey_\(serviceName)", service: "AuthProject")
    }
    
    func loadAPIKey(for serviceName: String) throws -> String {
        let apiKeyData = try loadData(for: "apikey_\(serviceName)", service: "AuthProject")
        guard let apiKey = String(data: apiKeyData, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return apiKey
    }
    
    func deleteAPIKey(for serviceName: String) throws {
        try deleteData(for: "apikey_\(serviceName)", service: "AuthProject")
    }
    
    // MARK: - OAuth Client Secrets
    
    func saveOAuthClientSecret(_ secret: String, for service: String) throws {
        let secretData = secret.data(using: .utf8)!
        try saveData(secretData, for: "client_secret_\(service)", service: "AuthProject")
    }
    
    func loadOAuthClientSecret(for service: String) throws -> String {
        let secretData = try loadData(for: "client_secret_\(service)", service: "AuthProject")
        guard let secret = String(data: secretData, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return secret
    }
    
    func hasOAuthClientSecret(for service: String) -> Bool {
        do {
            _ = try loadOAuthClientSecret(for: service)
            return true
        } catch {
            return false
        }
    }
    
    func deleteOAuthClientSecret(for service: String) throws {
        try deleteData(for: "client_secret_\(service)", service: "AuthProject")
    }
    
    // MARK: - Generic Keychain Operations
    
    private func saveData(_ data: Data, for key: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Item already exists, update it
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: service
            ]
            
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            
            if updateStatus != errSecSuccess {
                throw KeychainError.saveFailed(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.saveFailed(status)
        }
    }
    
    private func loadData(for key: String, service: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            throw KeychainError.itemNotFound
        } else if status != errSecSuccess {
            throw KeychainError.loadFailed(status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.dataConversionFailed
        }
        
        return data
    }
    
    private func deleteData(for key: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    // MARK: - Utility Methods
    
    func hasEncryptionKey() -> Bool {
        do {
            _ = try loadEncryptionKey()
            return true
        } catch {
            return false
        }
    }
    
    func hasOAuthCredentials(for serviceName: String) -> Bool {
        do {
            _ = try loadOAuthCredentials(for: serviceName)
            return true
        } catch {
            return false
        }
    }
    
    func hasAPIKey(for serviceName: String) -> Bool {
        do {
            _ = try loadAPIKey(for: serviceName)
            return true
        } catch {
            return false
        }
    }
    
    func getAllStoredServices() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "AuthProject",
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status != errSecSuccess {
            return []
        }
        
        guard let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item in
            item[kSecAttrAccount as String] as? String
        }
    }
}

// MARK: - Keychain Errors

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case itemNotFound
    case dataConversionFailed
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .loadFailed(let status):
            return "Failed to load from Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        case .itemNotFound:
            return "Item not found in Keychain"
        case .dataConversionFailed:
            return "Failed to convert data"
        }
    }
} 