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
        print("🔧 Main OAuth: Starting for service: '\(service.name)'")
        
        // For Google services with sensitive scopes, consider using Google Sign-In SDK
        // which handles the OAuth flow more reliably for iOS apps
        
        // Use Google Sign-In for Google services
        if service.name.contains("Google") {
            print("🔧 Main OAuth: Using Google Sign-In for: \(service.name)")
            // Check if we have a valid Google client ID
            let clientId = AppEnvironment.googleClientId
            if clientId.hasPrefix("YOUR_") {
                throw AuthenticationError.invalidConfiguration
            }
            return try await googleSignInService.authenticateWithGoogle(for: service)
        }
        
        // Special handling for Instagram (Facebook OAuth) - temporarily disabled
        // if service.name == "Instagram" {
        //     return try await authenticateWithFacebookOAuth(for: service)
        // }
        
        // Special handling for TikTok OAuth
        if service.name == "TikTok" {
            print("🔧 Main OAuth: Using TikTok OAuth for: \(service.name)")
            return try await authenticateWithTikTokOAuth(for: service)
        }
        
        // Special handling for X (Twitter) OAuth
        if service.name == "X (Twitter)" {
            print("🔧 Main OAuth: Using Twitter OAuth for: \(service.name)")
            return try await authenticateWithTwitterOAuth(for: service)
        }
        
        print("🔧 Main OAuth: Using generic OAuth for: \(service.name)")
        
        // Use web OAuth for other services (Microsoft, etc.)
        guard let oauthConfig = configManager.getOAuthConfig(for: service.name) else {
            print("❌ Main OAuth: No OAuth config found for service: \(service.name)")
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
                            config: oauthConfig,
                            state: state
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
    
    private func exchangeAuthCodeForTokens(authCode: String, config: OAuthConfig, state: String? = nil) async throws -> OAuthCredentials {
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
        
        // Add PKCE code verifier for public clients
        if config.isPublicClient {
            // Try to get the stored code verifier using state
            if let state = state {
                let storedCodeVerifier = UserDefaults.standard.string(forKey: "pkce_code_verifier_\(state)")
                if let codeVerifier = storedCodeVerifier {
                    requestBody["code_verifier"] = codeVerifier
                    print("🔧 PKCE: Added code verifier to token exchange")
                    // Clean up the stored code verifier
                    UserDefaults.standard.removeObject(forKey: "pkce_code_verifier_\(state)")
                }
            }
        }
        
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
    
    // MARK: - API Key Authentication
    
    func authenticateWithAPIKey(for service: IntegrationService, apiKey: String) async throws -> APIKeyCredentials {
        // Validate API key format (basic validation)
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthenticationError.invalidAPIKey
        }
        
        // Special handling for Twilio (Account SID + Auth Token)
        if service.name == "Twilio" {
            return try await authenticateWithTwilio(apiKey: apiKey)
        }
        
        // Special handling for SendGrid (API Key)
        if service.name == "SendGrid" {
            return try await authenticateWithSendGrid(apiKey: apiKey)
        }
        
        // Simulate API key validation for other services
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // For demo purposes, we'll accept any non-empty API key
        let credentials = APIKeyCredentials(
            apiKey: apiKey,
            additionalData: [
                "validated_at": ISO8601DateFormatter().string(from: Date()),
                "service": service.name,
                "demo_mode": "true"
            ]
        )
        
        return credentials
    }
    
    // MARK: - Twilio Authentication
    
    private func authenticateWithTwilio(apiKey: String) async throws -> APIKeyCredentials {
        // Parse the API key (should be in format "AccountSID:AuthToken")
        let components = apiKey.components(separatedBy: ":")
        guard components.count == 2 else {
            throw AuthenticationError.twilioInvalidFormat
        }
        
        let accountSid = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let authToken = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate Account SID format (should start with AC)
        guard accountSid.hasPrefix("AC") && accountSid.count >= 32 else {
            throw AuthenticationError.twilioInvalidCredentials
        }
        
        // Validate Auth Token format (should be 32 characters)
        guard authToken.count >= 32 else {
            throw AuthenticationError.twilioInvalidCredentials
        }
        
        // Make a real API call to validate credentials
        let url = URL(string: "https://api.twilio.com/2010-04-01/Accounts/\(accountSid).json")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add Basic Auth header
        let credentials = "\(accountSid):\(authToken)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw AuthenticationError.invalidAPIKey
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthenticationError.networkError
            }
            
            if httpResponse.statusCode == 200 {
                // Successfully authenticated
                // Parse the response to get account details
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accountName = json["friendly_name"] as? String {
                    
                    return APIKeyCredentials(
                        apiKey: apiKey,
                        additionalData: [
                            "account_sid": accountSid,
                            "auth_token": authToken,
                            "account_name": accountName,
                            "validated_at": ISO8601DateFormatter().string(from: Date()),
                            "service": "Twilio"
                        ]
                    )
                } else {
                    // Still valid even if we can't parse the response
                    return APIKeyCredentials(
                        apiKey: apiKey,
                        additionalData: [
                            "account_sid": accountSid,
                            "auth_token": authToken,
                            "validated_at": ISO8601DateFormatter().string(from: Date()),
                            "service": "Twilio"
                        ]
                    )
                }
            } else {
                // Handle specific Twilio error codes
                if httpResponse.statusCode == 401 {
                    throw AuthenticationError.twilioInvalidCredentials
                } else if httpResponse.statusCode == 404 {
                    throw AuthenticationError.twilioInvalidCredentials
                } else {
                    throw AuthenticationError.networkError
                }
            }
        } catch {
            throw AuthenticationError.networkError
        }
    }
    
    // MARK: - SendGrid Authentication
    
    private func authenticateWithSendGrid(apiKey: String) async throws -> APIKeyCredentials {
        // Validate API key format (SendGrid API keys are typically 69 characters)
        guard apiKey.count >= 50 && apiKey.count <= 100 else {
            throw AuthenticationError.invalidAPIKey
        }
        
        // Make a real API call to validate credentials
        let url = URL(string: "https://api.sendgrid.com/v3/user/profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthenticationError.networkError
            }
            
            if httpResponse.statusCode == 200 {
                // Successfully authenticated
                // Parse the response to get user details
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let email = json["email"] as? String {
                    
                    return APIKeyCredentials(
                        apiKey: apiKey,
                        additionalData: [
                            "email": email,
                            "validated_at": ISO8601DateFormatter().string(from: Date()),
                            "service": "SendGrid"
                        ]
                    )
                } else {
                    // Still valid even if we can't parse the response
                    return APIKeyCredentials(
                        apiKey: apiKey,
                        additionalData: [
                            "validated_at": ISO8601DateFormatter().string(from: Date()),
                            "service": "SendGrid"
                        ]
                    )
                }
            } else {
                // Handle specific SendGrid error codes
                if httpResponse.statusCode == 401 {
                    throw AuthenticationError.sendGridInvalidCredentials
                } else if httpResponse.statusCode == 403 {
                    throw AuthenticationError.sendGridInvalidCredentials
                } else {
                    throw AuthenticationError.networkError
                }
            }
        } catch {
            throw AuthenticationError.networkError
        }
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
    
    // MARK: - TikTok OAuth
    
    private func authenticateWithTikTokOAuth(for service: IntegrationService) async throws -> OAuthCredentials {
        guard let oauthConfig = configManager.getOAuthConfig(for: service.name) else {
            throw AuthenticationError.oauthFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let state = UUID().uuidString
            let authorizationURL = configManager.generateAuthorizationURL(for: oauthConfig, state: state)
            
            // Use https scheme to handle localhost redirect
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: "https"
            ) { callbackURL, error in
                if let error = error {
                    print("TikTok OAuth error: \(error)")
                    continuation.resume(throwing: AuthenticationError.oauthFailed)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    print("No callback URL received from TikTok OAuth")
                    continuation.resume(throwing: AuthenticationError.oauthCancelled)
                    return
                }
                
                print("Received TikTok callback URL: \(callbackURL)")
                
                // Check if this is the localhost redirect with authorization code
                if callbackURL.host == "localhost" {
                    // Extract authorization code from localhost URL
                    guard let authCode = self.configManager.extractAuthCode(from: callbackURL) else {
                        print("Failed to extract auth code from localhost callback URL")
                        continuation.resume(throwing: AuthenticationError.invalidResponse)
                        return
                    }
                    
                    print("Successfully extracted auth code from localhost redirect")
                    
                    // Exchange auth code for tokens
                    Task {
                        do {
                            let tokens = try await self.exchangeAuthCodeForTokens(
                                authCode: authCode,
                                config: oauthConfig,
                                state: state
                            )
                            continuation.resume(returning: tokens)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    return
                }
                
                // Fallback: Try to extract authorization code from any callback URL
                guard let authCode = self.configManager.extractAuthCode(from: callbackURL) else {
                    print("Failed to extract auth code from TikTok callback URL")
                    continuation.resume(throwing: AuthenticationError.invalidResponse)
                    return
                }
                
                print("Fallback: extracted auth code from TikTok OAuth")
                
                // Exchange auth code for tokens
                Task {
                    do {
                        let tokens = try await self.exchangeAuthCodeForTokens(
                            authCode: authCode,
                            config: oauthConfig,
                            state: state
                        )
                        continuation.resume(returning: tokens)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
    
    // MARK: - X (Twitter) OAuth
    
    private func authenticateWithTwitterOAuth(for service: IntegrationService) async throws -> OAuthCredentials {
        guard let oauthConfig = configManager.getOAuthConfig(for: service.name) else {
            throw AuthenticationError.oauthFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let state = UUID().uuidString
            let authorizationURL = configManager.generateAuthorizationURL(for: oauthConfig, state: state)
            
            // Use custom URL scheme for proper iOS app behavior
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: oauthConfig.callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    // Handle specific error codes
                    if let webAuthError = error as? ASWebAuthenticationSessionError {
                        switch webAuthError.code {
                        case .canceledLogin:
                            continuation.resume(throwing: AuthenticationError.oauthCancelled)
                        case .presentationContextNotProvided:
                            continuation.resume(throwing: AuthenticationError.oauthFailed)
                        case .presentationContextInvalid:
                            continuation.resume(throwing: AuthenticationError.oauthFailed)
                        @unknown default:
                            continuation.resume(throwing: AuthenticationError.oauthFailed)
                        }
                    } else {
                        continuation.resume(throwing: AuthenticationError.oauthFailed)
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AuthenticationError.oauthCancelled)
                    return
                }
                
                // Extract authorization code from callback URL
                guard let authCode = self.configManager.extractAuthCode(from: callbackURL) else {
                    continuation.resume(throwing: AuthenticationError.invalidResponse)
                    return
                }
                
                // Exchange auth code for tokens
                Task {
                    do {
                        let tokens = try await self.exchangeAuthCodeForTokens(
                            authCode: authCode,
                            config: oauthConfig,
                            state: state
                        )
                        continuation.resume(returning: tokens)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true // Force fresh session to clear any cached state
            
            session.start()
        }
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
    case twilioInvalidFormat
    case twilioInvalidCredentials
    case sendGridInvalidCredentials
    
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
        case .twilioInvalidFormat:
            return "Invalid Twilio credentials format. Expected: AccountSID:AuthToken"
        case .twilioInvalidCredentials:
            return "Invalid Twilio credentials. Please check your Account SID and Auth Token are correct and try again."
        case .sendGridInvalidCredentials:
            return "Invalid SendGrid API key. Please check your API key is correct and try again."
        }
    }
} 
