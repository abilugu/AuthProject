import Foundation
import GoogleSignIn
import GoogleSignInSwift

class GoogleSignInService: ObservableObject {
    static let shared = GoogleSignInService()
    
    private let storageService = StorageService.shared
    private let encryptionService = EncryptionService.shared
    
    private init() {}
    
    // MARK: - Google Sign-In Configuration
    
    func configure() {
        print("=== Google Sign-In Configuration Debug ===")
        
        // First, let's check if the URL scheme is properly registered
        checkURLSchemes()
        
        // Use environment variable for client ID
        let clientId = AppEnvironment.googleClientId
        
        print("✓ Google Sign-In Configuration:")
        print("  CLIENT_ID: \(clientId)")
        print("  REVERSED_CLIENT_ID: com.googleusercontent.apps.566190706008-htm515doi2ee1knno6d19tb0lei5n7ub")
        
        // Configure Google Sign-In with error handling
        do {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
            print("✓ GIDSignIn configured successfully")
        } catch {
            print("ERROR: Failed to configure GIDSignIn: \(error)")
        }
        
        print("=== End Google Sign-In Configuration Debug ===")
    }
    
    private func checkURLSchemes() {
        print("Checking URL schemes in Info.plist...")
        
        // Check which Info.plist is being used
        if let infoPlistPath = Bundle.main.path(forResource: "Info", ofType: "plist") {
            print("Info.plist path: \(infoPlistPath)")
        } else {
            print("ERROR: Could not find Info.plist path")
        }
        
        // Check the actual info dictionary
        if let infoDictionary = Bundle.main.infoDictionary {
            print("Info dictionary keys: \(infoDictionary.keys)")
            
            if let urlTypes = infoDictionary["CFBundleURLTypes"] as? [[String: Any]] {
                print("Found \(urlTypes.count) URL types:")
                for (index, urlType) in urlTypes.enumerated() {
                    if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
                        print("  URL Type \(index): \(schemes)")
                        
                        // Check if the Google URL scheme is present
                        let expectedScheme = "com.googleusercontent.apps.566190706008-htm515doi2ee1knno6d19tb0lei5n7ub"
                        if schemes.contains(expectedScheme) {
                            print("✓ Found Google URL scheme: \(expectedScheme)")
                        } else {
                            print("✗ Missing Google URL scheme: \(expectedScheme)")
                        }
                    }
                }
            } else {
                print("ERROR: No URL types found in Info.plist")
                print("Available keys in info dictionary: \(infoDictionary.keys)")
            }
        } else {
            print("ERROR: Could not access info dictionary")
        }
        
        // Also check if the URL scheme can be handled
        let expectedScheme = "com.googleusercontent.apps.566190706008-htm515doi2ee1knno6d19tb0lei5n7ub"
        if let url = URL(string: "\(expectedScheme)://test") {
            if UIApplication.shared.canOpenURL(url) {
                print("✓ URL scheme can be opened: \(expectedScheme)")
            } else {
                print("✗ URL scheme cannot be opened: \(expectedScheme)")
            }
        }
    }
    
    // MARK: - Authentication
    
    func authenticateWithGoogle(for service: IntegrationService) async throws -> OAuthCredentials {
        // Note: Google Sign-In SDK automatically handles scope requests
        // The scope is determined by the Google Cloud Console OAuth client configuration
        // and the APIs that are enabled for your project
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    // Ensure we're on the main thread for UI operations
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let window = windowScene.windows.first,
                          let rootViewController = window.rootViewController else {
                        continuation.resume(throwing: AuthenticationError.invalidConfiguration)
                        return
                    }
                    
                    // Get the appropriate scope for the service (for reference)
                    let scope = getScopeForService(service.name)
                    
                    // Get the topmost view controller (on main thread)
                    let topViewController = getTopViewController(from: rootViewController)
                    
                    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: topViewController)
                    
                    // Extract OAuth tokens
                    let accessToken = result.user.accessToken.tokenString
                    let refreshToken = result.user.refreshToken.tokenString
                    let expiresAt = result.user.accessToken.expirationDate
                    
                    // Create OAuth credentials
                    let credentials = OAuthCredentials(
                        accessToken: accessToken,
                        refreshToken: refreshToken,
                        expiresAt: expiresAt,
                        scope: scope
                    )
                    
                    continuation.resume(returning: credentials)
                } catch {
                    print("Google Sign-In error: \(error)")
                    if let signInError = error as? GIDSignInError {
                        switch signInError.code {
                        case .canceled:
                            continuation.resume(throwing: AuthenticationError.oauthCancelled)
                        case .hasNoAuthInKeychain:
                            continuation.resume(throwing: AuthenticationError.oauthFailed)
                        default:
                            continuation.resume(throwing: AuthenticationError.oauthFailed)
                        }
                    } else {
                        continuation.resume(throwing: AuthenticationError.oauthFailed)
                    }
                }
            }
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
    
    // MARK: - Check Sign-In Status
    
    func isSignedIn() -> Bool {
        return GIDSignIn.sharedInstance.currentUser != nil
    }
    
    // MARK: - Get Current User
    
    func getCurrentUser() -> GIDGoogleUser? {
        return GIDSignIn.sharedInstance.currentUser
    }
    
    // MARK: - Refresh Token
    
    func refreshToken() async throws -> OAuthCredentials? {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            return nil
        }
        
        do {
            let result = try await user.refreshTokensIfNeeded()
            
            let credentials = OAuthCredentials(
                accessToken: result.accessToken.tokenString,
                refreshToken: result.refreshToken.tokenString,
                expiresAt: result.accessToken.expirationDate,
                scope: nil // GIDToken doesn't have scope property
            )
            
            return credentials
        } catch {
            print("Failed to refresh Google token: \(error)")
            throw AuthenticationError.oauthFailed
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return getTopViewController(from: presented)
        }
        
        if let navigationController = viewController as? UINavigationController {
            return getTopViewController(from: navigationController.visibleViewController ?? navigationController)
        }
        
        if let tabBarController = viewController as? UITabBarController {
            return getTopViewController(from: tabBarController.selectedViewController ?? tabBarController)
        }
        
        return viewController
    }
    
    private func getScopeForService(_ serviceName: String) -> String? {
        switch serviceName {
        case "Google Calendar":
            return "https://www.googleapis.com/auth/calendar"
        case "Google Sheets":
            return "https://www.googleapis.com/auth/spreadsheets"
        case "Google Drive":
            return "https://www.googleapis.com/auth/drive"
        case "Gmail":
            return "https://www.googleapis.com/auth/gmail.modify"
        default:
            return nil
        }
    }
} 