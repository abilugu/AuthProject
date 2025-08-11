import Foundation

enum AppEnvironment {
    // MARK: - Google OAuth
    static let googleClientId: String = {
        let value = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"]
        if value == nil || value?.isEmpty == true {
            print("⚠️  GOOGLE_CLIENT_ID not set in environment variables")
            print("   Please set it in Xcode Scheme → Run → Arguments → Environment Variables")
            return "YOUR_GOOGLE_CLIENT_ID"
        }
        return value!
    }()
    
    // MARK: - Microsoft OAuth
    static let microsoftClientId: String = {
        let value = ProcessInfo.processInfo.environment["MICROSOFT_CLIENT_ID"]
        if value == nil || value?.isEmpty == true {
            print("⚠️  MICROSOFT_CLIENT_ID not set in environment variables")
            print("   Please set it in Xcode Scheme → Run → Arguments → Environment Variables")
            return "YOUR_MICROSOFT_CLIENT_ID"
        }
        return value!
    }()
    
    static let microsoftClientSecret: String = {
        let value = ProcessInfo.processInfo.environment["MICROSOFT_CLIENT_SECRET"]
        if value == nil || value?.isEmpty == true {
            print("⚠️  MICROSOFT_CLIENT_SECRET not set in environment variables")
            print("   Please set it in Xcode Scheme → Run → Arguments → Environment Variables")
            return "YOUR_MICROSOFT_CLIENT_SECRET"
        }
        return value!
    }()
    
    // MARK: - API Keys
    static let sendGridApiKey: String = {
        let value = ProcessInfo.processInfo.environment["SENDGRID_API_KEY"]
        if value == nil || value?.isEmpty == true {
            print("⚠️  SENDGRID_API_KEY not set in environment variables")
            print("   Please set it in Xcode Scheme → Run → Arguments → Environment Variables")
            return "YOUR_SENDGRID_API_KEY"
        }
        return value!
    }()
    
    static let twilioApiKey: String = {
        let value = ProcessInfo.processInfo.environment["TWILIO_API_KEY"]
        if value == nil || value?.isEmpty == true {
            print("⚠️  TWILIO_API_KEY not set in environment variables")
            print("   Please set it in Xcode Scheme → Run → Arguments → Environment Variables")
            return "YOUR_TWILIO_API_KEY"
        }
        return value!
    }()
    
    static let twilioAccountSid: String = {
        let value = ProcessInfo.processInfo.environment["TWILIO_ACCOUNT_SID"]
        if value == nil || value?.isEmpty == true {
            print("⚠️  TWILIO_ACCOUNT_SID not set in environment variables")
            print("   Please set it in Xcode Scheme → Run → Arguments → Environment Variables")
            return "YOUR_TWILIO_ACCOUNT_SID"
        }
        return value!
    }()
} 