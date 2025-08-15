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
    
    // MARK: - Instagram OAuth
    static let instagramClientId: String = {
        return ProcessInfo.processInfo.environment["INSTAGRAM_CLIENT_ID"] ?? "YOUR_INSTAGRAM_CLIENT_ID"
    }()
    
    static let instagramClientSecret: String = {
        return ProcessInfo.processInfo.environment["INSTAGRAM_CLIENT_SECRET"] ?? "YOUR_INSTAGRAM_CLIENT_SECRET"
    }()
    
    // MARK: - TikTok OAuth
    static let tiktokClientId: String = {
        return ProcessInfo.processInfo.environment["TIKTOK_CLIENT_ID"] ?? "YOUR_TIKTOK_CLIENT_ID"
    }()
    
    static let tiktokClientSecret: String = {
        return ProcessInfo.processInfo.environment["TIKTOK_CLIENT_SECRET"] ?? "YOUR_TIKTOK_CLIENT_SECRET"
    }()
    
    // MARK: - X (Twitter) OAuth
    static let twitterClientId: String = {
        return ProcessInfo.processInfo.environment["TWITTER_CLIENT_ID"] ?? "YOUR_TWITTER_CLIENT_ID"
    }()
    
    static let twitterClientSecret: String = {
        return ProcessInfo.processInfo.environment["TWITTER_CLIENT_SECRET"] ?? "YOUR_TWITTER_CLIENT_SECRET"
    }()
    
    // MARK: - LinkedIn OAuth
    static let linkedinClientId: String = {
        return ProcessInfo.processInfo.environment["LINKEDIN_CLIENT_ID"] ?? "YOUR_LINKEDIN_CLIENT_ID"
    }()
    
    static let linkedinClientSecret: String = {
        return ProcessInfo.processInfo.environment["LINKEDIN_CLIENT_SECRET"] ?? "YOUR_LINKEDIN_CLIENT_SECRET"
    }()
    
    // MARK: - Facebook OAuth
    static let facebookClientId: String = {
        return ProcessInfo.processInfo.environment["FACEBOOK_CLIENT_ID"] ?? "YOUR_FACEBOOK_CLIENT_ID"
    }()
    
    static let facebookClientSecret: String = {
        return ProcessInfo.processInfo.environment["FACEBOOK_CLIENT_SECRET"] ?? "YOUR_FACEBOOK_CLIENT_SECRET"
    }()
    
    // MARK: - Snapchat OAuth
    static let snapchatClientId: String = {
        return ProcessInfo.processInfo.environment["SNAPCHAT_CLIENT_ID"] ?? "YOUR_SNAPCHAT_CLIENT_ID"
    }()
    
    static let snapchatClientSecret: String = {
        return ProcessInfo.processInfo.environment["SNAPCHAT_CLIENT_SECRET"] ?? "YOUR_SNAPCHAT_CLIENT_SECRET"
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