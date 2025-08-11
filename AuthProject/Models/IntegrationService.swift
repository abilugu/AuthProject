import Foundation

enum AuthenticationType: String, CaseIterable, Codable {
    case oauth = "oauth"
    case apiKey = "api_key"
    
    var displayName: String {
        switch self {
        case .oauth:
            return "OAuth 2.0"
        case .apiKey:
            return "API Key"
        }
    }
}

enum ConnectionStatus: String, CaseIterable, Codable {
    case disconnected = "disconnected"
    case connected = "connected"
    case connecting = "connecting"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .error:
            return "Error"
        }
    }
    
    var color: String {
        switch self {
        case .disconnected:
            return "red"
        case .connected:
            return "green"
        case .connecting:
            return "orange"
        case .error:
            return "red"
        }
    }
}

struct IntegrationService: Identifiable, Codable {
    let id = UUID()
    let name: String
    let icon: String
    let authenticationType: AuthenticationType
    var connectionStatus: ConnectionStatus
    
    init(name: String, icon: String, authenticationType: AuthenticationType) {
        self.name = name
        self.icon = icon
        self.authenticationType = authenticationType
        self.connectionStatus = .disconnected
    }
}

struct OAuthCredentials: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let scope: String?
}

struct APIKeyCredentials: Codable {
    let apiKey: String
    let additionalData: [String: String]?
} 