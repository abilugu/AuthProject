import Foundation

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
        default:
            return []
        }
    }
    
    func generateAuthorizationURL(for config: OAuthConfig, state: String) -> URL {
        var components = URLComponents(url: config.authorizationURL, resolvingAgainstBaseURL: false)!
        
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
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
} 
