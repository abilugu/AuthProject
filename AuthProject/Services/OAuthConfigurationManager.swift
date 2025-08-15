import Foundation
import CryptoKit

class OAuthConfigurationManager {
    static let shared = OAuthConfigurationManager()
    private let keychainService = KeychainService.shared
    
    private init() {}
    
    func getOAuthConfig(for serviceName: String) -> OAuthConfig? {
        switch serviceName {
        case let name where name.contains("Google"):
            return OAuthConfig(
                clientId: AppEnvironment.googleClientId,
                clientSecret: "", // Google iOS OAuth doesn't use client secrets
                authorizationURL: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
                tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
                callbackScheme: "com.googleusercontent.apps.566190706008-htm515doi2ee1knno6d19tb0lei5n7ub",
                scopes: getScopesForService(serviceName),
                redirectURI: "com.googleusercontent.apps.566190706008-htm515doi2ee1knno6d19tb0lei5n7ub:/",
                isPublicClient: true
            )
        case let name where name.contains("Office") || name.contains("OneDrive"):
            return OAuthConfig(
                clientId: AppEnvironment.microsoftClientId,
                clientSecret: AppEnvironment.microsoftClientSecret,
                authorizationURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
                tokenURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!,
                callbackScheme: "authproject",
                scopes: getScopesForService(serviceName),
                redirectURI: "authproject://oauth/callback",
                isPublicClient: true
            )
        case "Instagram":
            return OAuthConfig(
                clientId: AppEnvironment.instagramClientId,
                clientSecret: AppEnvironment.instagramClientSecret,
                authorizationURL: URL(string: "https://www.facebook.com/v18.0/dialog/oauth")!,
                tokenURL: URL(string: "https://graph.facebook.com/v18.0/oauth/access_token")!,
                callbackScheme: "authproject",
                scopes: getScopesForService(serviceName),
                redirectURI: "authproject://oauth/callback",
                isPublicClient: false
            )
        case "TikTok":
            return OAuthConfig(
                clientId: AppEnvironment.tiktokClientId,
                clientSecret: AppEnvironment.tiktokClientSecret,
                authorizationURL: URL(string: "https://www.tiktok.com/v2/auth/authorize")!,
                tokenURL: URL(string: "https://open.tiktokapis.com/v2/oauth/token/")!,
                callbackScheme: "https",
                scopes: getScopesForService(serviceName),
                redirectURI: "https://localhost/oauth/callback",
                isPublicClient: false
            )
        case "X (Twitter)":
            return OAuthConfig(
                clientId: AppEnvironment.twitterClientId,
                clientSecret: AppEnvironment.twitterClientSecret,
                authorizationURL: URL(string: "https://x.com/i/oauth2/authorize")!,
                tokenURL: URL(string: "https://api.x.com/2/oauth2/token")!,
                callbackScheme: "authproject",
                scopes: getScopesForService(serviceName),
                redirectURI: "authproject://oauth/callback",
                isPublicClient: false  // Match Android app configuration
            )
        case "LinkedIn":
            return OAuthConfig(
                clientId: AppEnvironment.linkedinClientId,
                clientSecret: AppEnvironment.linkedinClientSecret,
                authorizationURL: URL(string: "https://www.linkedin.com/oauth/v2/authorization")!,
                tokenURL: URL(string: "https://www.linkedin.com/oauth/v2/accessToken")!,
                callbackScheme: "authproject",
                scopes: getScopesForService(serviceName),
                redirectURI: "authproject://oauth/callback",
                isPublicClient: false
            )
        case "YouTube":
            return OAuthConfig(
                clientId: AppEnvironment.googleClientId,
                clientSecret: "", // Google iOS OAuth doesn't use client secrets
                authorizationURL: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
                tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
                callbackScheme: "com.googleusercontent.apps.566190706008-htm515doi2ee1knno6d19tb0lei5n7ub",
                scopes: getScopesForService(serviceName),
                redirectURI: "com.googleusercontent.apps.566190706008-htm515doi2ee1knno6d19tb0lei5n7ub:/",
                isPublicClient: true
            )
        case "Facebook":
            return OAuthConfig(
                clientId: AppEnvironment.facebookClientId,
                clientSecret: AppEnvironment.facebookClientSecret,
                authorizationURL: URL(string: "https://www.facebook.com/v18.0/dialog/oauth")!,
                tokenURL: URL(string: "https://graph.facebook.com/v18.0/oauth/access_token")!,
                callbackScheme: "authproject",
                scopes: getScopesForService(serviceName),
                redirectURI: "authproject://oauth/callback",
                isPublicClient: false
            )
        case "Snapchat":
            return OAuthConfig(
                clientId: AppEnvironment.snapchatClientId,
                clientSecret: AppEnvironment.snapchatClientSecret,
                authorizationURL: URL(string: "https://accounts.snapchat.com/accounts/oauth2/auth")!,
                tokenURL: URL(string: "https://accounts.snapchat.com/accounts/oauth2/token")!,
                callbackScheme: "authproject",
                scopes: getScopesForService(serviceName),
                redirectURI: "authproject://oauth/callback",
                isPublicClient: false
            )
        default:
            return nil
        }
    }
    
    private func getScopesForService(_ serviceName: String) -> [String] {
        switch serviceName {
        case let name where name.contains("Google Calendar"):
            return ["https://www.googleapis.com/auth/calendar"]
        case let name where name.contains("Google Sheets"):
            return ["https://www.googleapis.com/auth/spreadsheets"]
        case let name where name.contains("Google Drive"):
            return ["https://www.googleapis.com/auth/drive"]
        case let name where name.contains("Google Gmail"):
            return ["https://www.googleapis.com/auth/gmail.send"]
        case let name where name.contains("Office 365 Calendar"):
            return ["https://graph.microsoft.com/Calendars.ReadWrite", "offline_access"]
        case let name where name.contains("Office 365 Mail"):
            return ["https://graph.microsoft.com/Mail.Send", "offline_access"]
        case let name where name.contains("OneDrive"):
            return ["https://graph.microsoft.com/Files.ReadWrite", "offline_access"]
        case "Instagram":
            return ["instagram_basic", "instagram_content_publish", "pages_show_list"]
        case "TikTok":
            return ["user.info.basic", "user.info.profile", "user.info.stats", "video.list", "video.upload"]
        case "X (Twitter)":
            return ["tweet.read", "users.read", "offline.access"]
        case "LinkedIn":
            return ["r_liteprofile", "r_emailaddress", "w_member_social"]
        case "YouTube":
            return ["https://www.googleapis.com/auth/youtube", "https://www.googleapis.com/auth/youtube.upload"]
        case "Facebook":
            return ["email", "public_profile", "user_posts"]
        case "Snapchat":
            return ["https://auth.snapchat.com/oauth2/api/user.display_name", "https://auth.snapchat.com/oauth2/api/user.bitmoji.avatar"]
        default:
            return []
        }
    }
    
    func generateAuthorizationURL(for config: OAuthConfig, state: String) -> URL {
        var components = URLComponents(url: config.authorizationURL, resolvingAgainstBaseURL: false)!
        
        // Use authorization code flow for all services (including Twitter)
        let responseType = "code"
        
        var queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: responseType),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state)
        ]
        
        // Add PKCE for public clients (but not for Twitter to match Android app)
        if config.isPublicClient && !config.clientId.contains("twitter") && !config.clientId.contains("U3VYT1NISkt4WnhHUWc1SUdmeWw6MTpjaQ") {
            let codeVerifier = generateCodeVerifier()
            let codeChallenge = generateCodeChallenge(from: codeVerifier)
            
            // Store code verifier for later use in token exchange
            UserDefaults.standard.set(codeVerifier, forKey: "pkce_code_verifier_\(state)")
            
            queryItems.append(contentsOf: [
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ])
        }
        
        components.queryItems = queryItems
        
        // Only add these for Google services (not Twitter)
        if config.clientId.contains("googleusercontent") {
            components.queryItems?.append(contentsOf: [
                URLQueryItem(name: "access_type", value: "offline"),
                URLQueryItem(name: "prompt", value: "consent")
            ])
        }
        
        return components.url!
    }
    
    func extractAuthCode(from callbackURL: URL) -> String? {
        // Try query parameters first
        if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            return code
        }
        
        // Try fragment (for some OAuth providers)
        if let fragment = callbackURL.fragment {
            let fragmentItems = fragment.components(separatedBy: "&")
            for item in fragmentItems {
                let keyValue = item.components(separatedBy: "=")
                if keyValue.count == 2 && keyValue[0] == "code" {
                    return keyValue[1]
                }
            }
        }
        
        // Try path components (for some custom schemes)
        let pathComponents = callbackURL.pathComponents
        for (index, component) in pathComponents.enumerated() {
            if component == "code" && index + 1 < pathComponents.count {
                return pathComponents[index + 1]
            }
        }
        
        return nil
    }
    
    // MARK: - PKCE Helper Methods
    
    private func generateCodeVerifier() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        let length = 128
        var codeVerifier = ""
        
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<characters.count)
            let character = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
            codeVerifier.append(character)
        }
        
        return codeVerifier
    }
    
    private func generateCodeChallenge(from codeVerifier: String) -> String {
        guard let data = codeVerifier.data(using: .utf8) else {
            return codeVerifier
        }
        
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
} 
