import Foundation

struct OAuthConfig {
    let clientId: String
    let clientSecret: String
    let authorizationURL: URL
    let tokenURL: URL
    let callbackScheme: String
    let scopes: [String]
    let redirectURI: String
    let isPublicClient: Bool
    
    init(clientId: String, clientSecret: String, authorizationURL: URL, tokenURL: URL, callbackScheme: String, scopes: [String], redirectURI: String, isPublicClient: Bool = false) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.authorizationURL = authorizationURL
        self.tokenURL = tokenURL
        self.callbackScheme = callbackScheme
        self.scopes = scopes
        self.redirectURI = redirectURI
        self.isPublicClient = isPublicClient
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let scope: String?
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }
}

struct AuthCodeResponse {
    let code: String
    let state: String?
} 