import Foundation
import AuthenticationServices

class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()
    
    private let storageService = StorageService.shared
    private let configManager = OAuthConfigurationManager.shared
    private let googleSignInService = GoogleSignInService.shared
    
    private override init() {
        super.init()
    }
    
    // MARK: - OAuth Authentication
    
    func authenticateWithOAuth(for service: IntegrationService) async throws -> OAuthCredentials {
        // For Google services with sensitive scopes, consider using Google Sign-In SDK
        // which handles the OAuth flow more reliably for iOS apps
        
        // Use Google Sign-In for Google services
        if service.name.contains("Google") {
            // Check if we have a valid Google client ID
            let clientId = AppEnvironment.googleClientId
            if clientId.hasPrefix("YOUR_") {
                throw AuthenticationError.invalidConfiguration
            }
            return try await googleSignInService.authenticateWithGoogle(for: service)
        }
        
        // Use web OAuth for other services (Microsoft, etc.)
        guard let oauthConfig = configManager.getOAuthConfig(for: service.name) else {
            throw AuthenticationError.oauthFailed
        }
        
        // Check if we have valid client credentials
        guard !oauthConfig.clientId.isEmpty && !oauthConfig.clientSecret.isEmpty else {
            throw AuthenticationError.invalidConfiguration
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let state = UUID().uuidString
            let authorizationURL = configManager.generateAuthorizationURL(for: oauthConfig, state: state)
            
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: oauthConfig.callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    print("OAuth error: \(error)")
                    print("Error domain: \(error._domain)")
                    print("Error code: \(error._code)")
                    print("Error description: \(error.localizedDescription)")
                    
                    // Handle specific error codes
                    if let webAuthError = error as? ASWebAuthenticationSessionError {
                        switch webAuthError.code {
                        case .canceledLogin:
                            print("User cancelled the OAuth flow")
                            continuation.resume(throwing: AuthenticationError.oauthCancelled)
                        case .presentationContextNotProvided:
                            print("Presentation context not provided")
                            continuation.resume(throwing: AuthenticationError.oauthFailed)
                        case .presentationContextInvalid:
                            print("Presentation context invalid")
                            continuation.resume(throwing: AuthenticationError.oauthFailed)
                        @unknown default:
                            print("Unknown ASWebAuthenticationSession error")
                            continuation.resume(throwing: AuthenticationError.oauthFailed)
                        }
                    } else {
                        continuation.resume(throwing: AuthenticationError.oauthFailed)
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    print("No callback URL received")
                    continuation.resume(throwing: AuthenticationError.oauthCancelled)
                    return
                }
                
                print("Received callback URL: \(callbackURL)")
                
                // Check for OAuth errors in the callback URL
                if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                   let errorParam = components.queryItems?.first(where: { $0.name == "error" })?.value {
                    print("OAuth error received: \(errorParam)")
                    
                    // Handle specific Microsoft OAuth errors
                    switch errorParam {
                    case "server_error":
                        continuation.resume(throwing: AuthenticationError.oauthFailed)
                    case "access_denied":
                        continuation.resume(throwing: AuthenticationError.oauthCancelled)
                    case "invalid_request":
                        continuation.resume(throwing: AuthenticationError.invalidConfiguration)
                    default:
                        continuation.resume(throwing: AuthenticationError.oauthFailed)
                    }
                    return
                }
                
                // Extract authorization code from callback
                guard let authCode = self.configManager.extractAuthCode(from: callbackURL) else {
                    print("Failed to extract auth code from callback URL")
                    continuation.resume(throwing: AuthenticationError.invalidResponse)
                    return
                }
                
                print("Successfully extracted auth code")
                
                // Exchange auth code for tokens
                Task {
                    do {
                        let tokens = try await self.exchangeAuthCodeForTokens(
                            authCode: authCode,
                            config: oauthConfig
                        )
                        continuation.resume(returning: tokens)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Configure session for better reliability
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false // Keep session for better UX
            session.start()
        }
    }
    
    private func exchangeAuthCodeForTokens(authCode: String, config: OAuthConfig) async throws -> OAuthCredentials {
        var requestBody: [String: String] = [
            "grant_type": "authorization_code",
            "code": authCode,
            "redirect_uri": config.redirectURI
        ]
        
        // Only send client_secret for confidential clients
        // Public clients (like mobile apps) should not send client_secret
        if !config.isPublicClient && !config.clientSecret.isEmpty && config.clientSecret != "your-actual-microsoft-client-secret-value" {
            requestBody["client_secret"] = config.clientSecret
        }
        
        // Always send client_id
        requestBody["client_id"] = config.clientId
        
        let url = config.tokenURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody.percentEncoded()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.networkError
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Token exchange failed with status: \(httpResponse.statusCode)")
            print("Error response: \(errorResponse)")
            throw AuthenticationError.tokenExchangeFailed
        }
        
        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            // Validate if this looks like a real OAuth token
            let isRealAccessToken = validateOAuthToken(tokenResponse.accessToken)
            
            return OAuthCredentials(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                scope: tokenResponse.scope
            )
        } catch {
            print("Failed to decode token response: \(error)")
            print("Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw AuthenticationError.invalidResponse
        }
    }
    
    func refreshOAuthTokens(for service: IntegrationService) async throws -> OAuthCredentials {
        guard let oauthConfig = configManager.getOAuthConfig(for: service.name) else {
            throw AuthenticationError.oauthFailed
        }
        
        let (currentCredentials, _) = try storageService.getCredentials(for: service.name)
        guard let oauthCredentials = currentCredentials as? OAuthCredentials,
              let refreshToken = oauthCredentials.refreshToken else {
            throw AuthenticationError.oauthFailed
        }
        
        var requestBody: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": oauthConfig.clientId,
            "refresh_token": refreshToken
        ]
        
        // Only send client_secret for confidential clients
        if !oauthConfig.isPublicClient && !oauthConfig.clientSecret.isEmpty {
            requestBody["client_secret"] = oauthConfig.clientSecret
        }
        
        let url = oauthConfig.tokenURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody.percentEncoded()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.oauthFailed
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Refresh Token Failed: \(errorResponse)")
            throw AuthenticationError.oauthFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        let newCredentials = OAuthCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
            scope: tokenResponse.scope
        )
        
        // Update stored credentials
        try storageService.saveCredentials(for: service, credentials: newCredentials)
        
        return newCredentials
    }
    
    // MARK: - API Key Authentication (unchanged)
    
    func authenticateWithAPIKey(for service: IntegrationService, apiKey: String) async throws -> APIKeyCredentials {
        // Validate API key format (basic validation)
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthenticationError.invalidAPIKey
        }
        
        // Simulate API key validation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // For demo purposes, we'll accept any non-empty API key
        let credentials = APIKeyCredentials(
            apiKey: apiKey,
            additionalData: ["validated_at": ISO8601DateFormatter().string(from: Date())]
        )
        
        return credentials
    }
    
    func revokeOAuthTokens(for service: IntegrationService) async throws {
        // In a real app, this would call the service's token revocation endpoint
        // For demo purposes, we'll just simulate the process
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Remove stored credentials
        storageService.removeCredentials(for: service.name)
    }
    
    func validateStoredCredentials(for service: IntegrationService) async throws -> Bool {
        guard storageService.isServiceConnected(service.name) else {
            return false
        }
        
        do {
            let (credentials, _) = try storageService.getCredentials(for: service.name)
            
            switch service.authenticationType {
            case .oauth:
                if let oauthCredentials = credentials as? OAuthCredentials {
                    // Check if token is expired
                    if let expiresAt = oauthCredentials.expiresAt, expiresAt < Date() {
                        // Try to refresh the token
                        do {
                            _ = try await refreshOAuthTokens(for: service)
                            return true
                        } catch {
                            // Token refresh failed, remove credentials
                            storageService.removeCredentials(for: service.name)
                            return false
                        }
                    }
                    return true
                }
            case .apiKey:
                if let _ = credentials as? APIKeyCredentials {
                    return true
                }
            }
            
            return false
        } catch {
            // If we can't decrypt or access credentials, consider them invalid
            storageService.removeCredentials(for: service.name)
            return false
        }
    }
    
    // MARK: - Google OAuth with Sign-In SDK
    
    func authenticateWithGoogleSignIn(for service: IntegrationService) async throws -> OAuthCredentials {
        // This would use Google Sign-In SDK for more reliable OAuth
        // For now, we'll use the web OAuth flow but this is the recommended approach
        
        guard let oauthConfig = configManager.getOAuthConfig(for: service.name) else {
            throw AuthenticationError.oauthFailed
        }
        
        // Check if we have valid client credentials
        guard !oauthConfig.clientId.isEmpty && !oauthConfig.clientSecret.isEmpty else {
            throw AuthenticationError.invalidConfiguration
        }
        
        return try await authenticateWithOAuth(for: service)
    }
    
    // MARK: - Token Validation
    
    private func validateOAuthToken(_ token: String) -> Bool {
        // Real OAuth tokens typically have these characteristics:
        // 1. Reasonable length (usually 100-2000 characters)
        // 2. Various formats: JWT, Microsoft format, Google format, etc.
        // 3. Not placeholder text
        
        // Check length
        guard token.count >= 50 && token.count <= 5000 else {
            return false
        }
        
        // Check for placeholder text
        let placeholderTexts = [
            "your-", "YOUR_", "placeholder", "dummy", "test", "example",
            "access_token", "refresh_token", "api_key"
        ]
        
        for placeholder in placeholderTexts {
            if token.lowercased().contains(placeholder.lowercased()) {
                return false
            }
        }
        
        // Check for Microsoft token format (starts with specific patterns)
        if token.hasPrefix("EwA") || token.hasPrefix("M.C") {
            return true
        }
        
        // Check for JWT-like format (contains dots and base64-like characters)
        let jwtPattern = #"^[A-Za-z0-9+/=]+\.[A-Za-z0-9+/=]+\.[A-Za-z0-9+/=]+$"#
        let jwtRegex = try! NSRegularExpression(pattern: jwtPattern)
        let jwtMatches = jwtRegex.matches(in: token, range: NSRange(token.startIndex..., in: token))
        
        // Check for other OAuth token formats (long alphanumeric strings)
        let alphanumericPattern = #"^[A-Za-z0-9\-_\.!*$]+$"#
        let alphanumericRegex = try! NSRegularExpression(pattern: alphanumericPattern)
        let alphanumericMatches = alphanumericRegex.matches(in: token, range: NSRange(token.startIndex..., in: token))
        
        // Token is valid if it matches JWT format OR is a long alphanumeric string OR is Microsoft format
        return jwtMatches.count > 0 || (alphanumericMatches.count > 0 && token.count > 100)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthenticationService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Ensure we're on the main thread when accessing UIApplication
        if Thread.isMainThread {
            return getMainWindow()
        } else {
            // Dispatch to main thread if we're not already there
            return DispatchQueue.main.sync {
                getMainWindow()
            }
        }
    }
    
    private func getMainWindow() -> ASPresentationAnchor {
        // Get the main window for presenting the OAuth web view
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for OAuth presentation")
        }
        return window
    }
}

// MARK: - Helper Extensions

extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data? {
        return map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

enum AuthenticationError: Error, LocalizedError {
    case invalidAPIKey
    case oauthCancelled
    case oauthFailed
    case networkError
    case invalidResponse
    case invalidConfiguration
    case tokenExchangeFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key provided"
        case .oauthCancelled:
            return "OAuth authentication was cancelled"
        case .oauthFailed:
            return "OAuth authentication failed"
        case .networkError:
            return "Network error occurred"
        case .invalidResponse:
            return "Invalid response from service"
        case .invalidConfiguration:
            return "Invalid OAuth configuration"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        }
    }
} 
