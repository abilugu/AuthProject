import Foundation

struct AppEnvironment {
    // MARK: - Google Services
    static let googleClientId: String = {
        return ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? "YOUR_GOOGLE_CLIENT_ID"
    }()
    
    // MARK: - Microsoft Services
    static let microsoftClientId: String = {
        return ProcessInfo.processInfo.environment["MICROSOFT_CLIENT_ID"] ?? "YOUR_MICROSOFT_CLIENT_ID"
    }()
    
    static let microsoftClientSecret: String = {
        return ProcessInfo.processInfo.environment["MICROSOFT_CLIENT_SECRET"] ?? "YOUR_MICROSOFT_CLIENT_SECRET"
    }()
    
    // MARK: - API Key Services
    static let sendGridApiKey: String = {
        return ProcessInfo.processInfo.environment["SENDGRID_API_KEY"] ?? "YOUR_SENDGRID_API_KEY"
    }()
    
    static let twilioApiKey: String = {
        return ProcessInfo.processInfo.environment["TWILIO_API_KEY"] ?? "YOUR_TWILIO_API_KEY"
    }()
    
    static let twilioAccountSid: String = {
        return ProcessInfo.processInfo.environment["TWILIO_ACCOUNT_SID"] ?? "YOUR_TWILIO_ACCOUNT_SID"
    }()
} 