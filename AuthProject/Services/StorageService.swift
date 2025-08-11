import Foundation

class StorageService {
    static let shared = StorageService()
    
    private let userDefaults = UserDefaults.standard
    private let encryptionService = EncryptionService.shared
    
    private init() {}
    
    // MARK: - Save Credentials
    
    func saveCredentials(for service: IntegrationService, credentials: Any) throws {
        let credentialData: Data
        let authType: String
        
        switch service.authenticationType {
        case .oauth:
            guard let oauthCredentials = credentials as? OAuthCredentials else {
                throw StorageError.invalidCredentialsType
            }
            credentialData = try JSONEncoder().encode(oauthCredentials)
            authType = "oauth"
            
        case .apiKey:
            guard let apiKeyCredentials = credentials as? APIKeyCredentials else {
                throw StorageError.invalidCredentialsType
            }
            credentialData = try JSONEncoder().encode(apiKeyCredentials)
            authType = "api_key"
        }
        
        // Encrypt the credential data
        let encryptedResult = try encryptionService.encrypt(credentialData)
        
        // Create the storage format
        let storageData = EncryptedStorageData(
            service: service.name,
            authType: authType,
            encryptedData: encryptedResult.encryptedData.base64EncodedString(),
            iv: encryptedResult.iv.base64EncodedString(),
            createdAt: Date()
        )
        
        // Store in UserDefaults
        let storageJson = try JSONEncoder().encode(storageData)
        userDefaults.set(storageJson, forKey: "credentials_\(service.name)")
        
        // Also store metadata for easy access
        let metadata = ServiceMetadata(
            serviceName: service.name,
            authenticationType: service.authenticationType,
            createdAt: Date(),
            lastUpdated: Date(),
            connectionStatus: .connected
        )
        saveServiceMetadata(metadata)
    }
    
    // MARK: - Get Credentials
    
    func getCredentials(for serviceName: String) throws -> (credentials: Any, metadata: ServiceMetadata) {
        // Get metadata from UserDefaults
        guard let metadata = getServiceMetadata(for: serviceName) else {
            throw StorageError.credentialsNotFound
        }
        
        // Get encrypted storage data
        guard let storageJson = userDefaults.data(forKey: "credentials_\(serviceName)"),
              let storageData = try? JSONDecoder().decode(EncryptedStorageData.self, from: storageJson) else {
            throw StorageError.credentialsNotFound
        }
        
        // Decode base64 strings
        guard let encryptedData = Data(base64Encoded: storageData.encryptedData),
              let iv = Data(base64Encoded: storageData.iv) else {
            throw StorageError.credentialsNotFound
        }
        
        // Decrypt the data
        let decryptedData = try encryptionService.decrypt(encryptedData: encryptedData, iv: iv)
        
        // Decode the credentials based on authentication type
        switch metadata.authenticationType {
        case .oauth:
            let oauthCredentials = try JSONDecoder().decode(OAuthCredentials.self, from: decryptedData)
            return (credentials: oauthCredentials, metadata: metadata)
            
        case .apiKey:
            let apiKeyCredentials = try JSONDecoder().decode(APIKeyCredentials.self, from: decryptedData)
            return (credentials: apiKeyCredentials, metadata: metadata)
        }
    }
    
    // MARK: - Remove Credentials
    
    func removeCredentials(for serviceName: String) {
        // Remove encrypted data from UserDefaults
        userDefaults.removeObject(forKey: "credentials_\(serviceName)")
        
        // Remove metadata from UserDefaults
        removeServiceMetadata(for: serviceName)
    }
    
    // MARK: - Get All Services
    
    func getAllStoredServices() -> [ServiceMetadata] {
        let allKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("metadata_") }
        var services: [ServiceMetadata] = []
        
        for key in allKeys {
            if let data = userDefaults.data(forKey: key),
               let metadata = try? JSONDecoder().decode(ServiceMetadata.self, from: data) {
                services.append(metadata)
            }
        }
        
        return services.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Service Status
    
    func isServiceConnected(_ serviceName: String) -> Bool {
        // Check if we have encrypted data for this service
        return userDefaults.object(forKey: "credentials_\(serviceName)") != nil
    }
    
    // MARK: - Update Service Status
    
    func updateServiceStatus(_ serviceName: String, status: ConnectionStatus) {
        guard var metadata = getServiceMetadata(for: serviceName) else { return }
        metadata.connectionStatus = status
        metadata.lastUpdated = Date()
        saveServiceMetadata(metadata)
    }
    
    // MARK: - Private Helper Methods
    
    private func saveServiceMetadata(_ metadata: ServiceMetadata) {
        let data = try! JSONEncoder().encode(metadata)
        userDefaults.set(data, forKey: "metadata_\(metadata.serviceName)")
    }
    
    private func getServiceMetadata(for serviceName: String) -> ServiceMetadata? {
        guard let data = userDefaults.data(forKey: "metadata_\(serviceName)") else {
            return nil
        }
        return try? JSONDecoder().decode(ServiceMetadata.self, from: data)
    }
    
    private func removeServiceMetadata(for serviceName: String) {
        userDefaults.removeObject(forKey: "metadata_\(serviceName)")
    }
}

// MARK: - Encrypted Storage Data Model

struct EncryptedStorageData: Codable {
    let service: String
    let authType: String
    let encryptedData: String  // base64-encoded encrypted credentials
    let iv: String            // base64-encoded initialization vector
    let createdAt: Date
}

// MARK: - Service Metadata Model

struct ServiceMetadata: Codable, Identifiable {
    let id = UUID()
    let serviceName: String
    let authenticationType: AuthenticationType
    let createdAt: Date
    var lastUpdated: Date
    var connectionStatus: ConnectionStatus
}

enum StorageError: Error, LocalizedError {
    case invalidCredentialsType
    case credentialsNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentialsType:
            return "Invalid credentials type"
        case .credentialsNotFound:
            return "Credentials not found"
        }
    }
} 