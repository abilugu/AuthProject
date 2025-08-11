import Foundation
import CryptoKit

class EncryptionService {
    static let shared = EncryptionService()
    
    private var encryptionKey: SymmetricKey?
    private let keychainService = KeychainService.shared
    
    private init() {
        loadEncryptionKey()
    }
    
    private func loadEncryptionKey() {
        // Try to load from Keychain
        if keychainService.hasEncryptionKey() {
            do {
                encryptionKey = try keychainService.loadEncryptionKey()
                return
            } catch {
                print("Failed to load encryption key from Keychain: \(error)")
            }
        }
        
        // Generate new key if none exists
        let newKey = SymmetricKey(size: .bits256)
        encryptionKey = newKey
        
        // Save to Keychain
        do {
            try keychainService.saveEncryptionKey(newKey)
            print("Generated and saved new encryption key to Keychain")
        } catch {
            print("Failed to save encryption key to Keychain: \(error)")
        }
    }
    
    func encrypt(_ data: Data) throws -> (encryptedData: Data, iv: Data) {
        guard let key = encryptionKey else {
            throw EncryptionError.noKeyAvailable
        }
        
        let iv = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: iv)
        
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return (encryptedData: encryptedData, iv: iv.withUnsafeBytes { Data($0) })
    }
    
    func decrypt(encryptedData: Data, iv: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw EncryptionError.noKeyAvailable
        }
        
        guard let nonce = try? AES.GCM.Nonce(data: iv) else {
            throw EncryptionError.invalidIV
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        return decryptedData
    }
    
    func encryptString(_ string: String) throws -> (encryptedData: String, iv: String) {
        let data = string.data(using: .utf8)!
        let (encryptedData, iv) = try encrypt(data)
        return (
            encryptedData: encryptedData.base64EncodedString(),
            iv: iv.base64EncodedString()
        )
    }
    
    func decryptString(encryptedData: String, iv: String) throws -> String {
        guard let encryptedDataBytes = Data(base64Encoded: encryptedData),
              let ivBytes = Data(base64Encoded: iv) else {
            throw EncryptionError.invalidData
        }
        
        let decryptedData = try decrypt(encryptedData: encryptedDataBytes, iv: ivBytes)
        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        
        return decryptedString
    }
    
    func regenerateEncryptionKey() throws {
        let newKey = SymmetricKey(size: .bits256)
        try keychainService.saveEncryptionKey(newKey)
        encryptionKey = newKey
    }
    
    func isKeyStoredInKeychain() -> Bool {
        return keychainService.hasEncryptionKey()
    }
}

enum EncryptionError: Error, LocalizedError {
    case noKeyAvailable
    case encryptionFailed
    case decryptionFailed
    case invalidIV
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .noKeyAvailable:
            return "No encryption key available"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidIV:
            return "Invalid initialization vector"
        case .invalidData:
            return "Invalid data format"
        }
    }
} 