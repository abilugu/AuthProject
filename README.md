# Integration Authentication Platform

A comprehensive iOS application built with SwiftUI and MVVM architecture that demonstrates real OAuth 2.0 and API key authentication for multiple third-party services.

## Features

### 🔐 Authentication Methods
- **OAuth 2.0**: Google Calendar, Google Sheets, Google Drive, Gmail, Office 365 Calendar, Office 365 Mail, OneDrive, Instagram, TikTok, X (Twitter), YouTube, Facebook, LinkedIn, Snapchat
- **API Key**: SendGrid, Twilio

### 🛡️ Security Features
- AES-256-GCM encryption for all stored credentials
- Unique initialization vectors (IV) for each credential
- Secure credential storage in iOS Keychain
- Environment variable configuration for sensitive data
- Token masking in UI for security

## Architecture

### MVVM Pattern
- **Models**: `IntegrationService`, `ServiceMetadata`, `OAuthCredentials`, `APIKeyCredentials`
- **ViewModels**: `IntegrationViewModel` (manages business logic and state)
- **Views**: `DashboardView`, `CredentialsView`, `MainTabView`

### Services Layer
- **EncryptionService**: Handles AES-256-GCM encryption/decryption with Keychain storage
- **StorageService**: Manages credential storage (Keychain for sensitive, UserDefaults for metadata)
- **AuthenticationService**: Handles OAuth flows and API key validation
- **GoogleSignInService**: Manages Google OAuth using Google Sign-In SDK
- **KeychainService**: Secure storage for sensitive data

## Setup Instructions

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- macOS 14.0 or later (for development)

### Environment Configuration

1. **Create Environment File**
   Create a `.env` file in the project root:

   ```bash
   # Google OAuth
   GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
   
   # Microsoft OAuth  
   MICROSOFT_CLIENT_ID=your-microsoft-client-id
   MICROSOFT_CLIENT_SECRET=your-microsoft-client-secret
   
   # API Keys
   SENDGRID_API_KEY=your-sendgrid-api-key
   TWILIO_API_KEY=your-twilio-api-key
   ```

2. **Load Environment Variables**
   ```bash
   source load_env.sh
   ```

3. **OAuth Configuration**
   ## 🔧 **Step 2: Google OAuth Setup**

### **3.1 Create Google Cloud Project**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the APIs you need:
   - Google Calendar API
   - Google Sheets API
   - Google Drive API
   - Gmail API

### **3.2 Configure OAuth Consent Screen**
1. Go to "APIs & Services" → "OAuth consent screen"
2. Choose "External" user type
3. Fill in required information:
   - App name: "AuthProject"
   - User support email: your email
   - Developer contact information: your email
4. Add scopes:
   - `https://www.googleapis.com/auth/calendar`
   - `https://www.googleapis.com/auth/spreadsheets`
   - `https://www.googleapis.com/auth/drive`
   - `https://www.googleapis.com/auth/gmail.modify`

### **3.3 Create OAuth 2.0 Credentials**
1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth 2.0 Client IDs"
3. **Choose "iOS" as application type** (not Web)
4. Add your bundle identifier: `com.playground.AuthProject`
5. Copy the Client ID

### **3.4 Update Configuration**
1. Update your `.env` file with the Google Client ID
2. The app uses Google Sign-In SDK which handles OAuth automatically
3. No need to configure redirect URIs manually

## 🔧 **Step 4: Microsoft OAuth Setup**

### **4.1 Create Azure App Registration**
1. Go to [Azure Portal](https://portal.azure.com/)
2. Navigate to "Azure Active Directory" → "App registrations"
3. Click "New registration"
4. Fill in details:
   - Name: "AuthProject"
   - **Supported account types: "Accounts in any organizational directory and personal Microsoft accounts"**
   - Redirect URI: `authproject://oauth/callback`

### **4.2 Configure API Permissions**
1. Go to "API permissions"
2. Add permissions:
   - Microsoft Graph → Calendars.ReadWrite
   - Microsoft Graph → Mail.ReadWrite
   - Microsoft Graph → Files.ReadWrite
3. Grant admin consent

### **4.3 Get Client Credentials**
1. Go to "Certificates & secrets"
2. Create a new client secret
3. Copy the Application (client) ID and Client Secret Value (not the ID)

### **4.4 Update Configuration**
Update your `.env` file with the Microsoft credentials:

```bash
MICROSOFT_CLIENT_ID=your-actual-microsoft-client-id
MICROSOFT_CLIENT_SECRET=your-actual-microsoft-client-secret-value
```

## Security Implementation

### Storage Architecture
- **Sensitive Data**: OAuth tokens, API keys stored directly in iOS Keychain
- **Non-sensitive Data**: Service metadata stored in UserDefaults
- **Encryption**: AES-256-GCM with unique IVs per credential
- **Key Management**: Automatic generation and storage in Keychain

### Environment Variables
- Client IDs and secrets loaded from environment variables
- Fallback values provided for development
- No hardcoded secrets in source code
