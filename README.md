# Integration Authentication Platform

A comprehensive iOS application built with SwiftUI and MVVM architecture that demonstrates real OAuth 2.0 and API key authentication for multiple third-party services.

## 🎥 Video Demonstration

![AuthProject Demo](demo/AuthProject-Demo.mp4)

**Watch the full demonstration** to see the Integration Authentication Platform in action:

- 🔐 **OAuth 2.0 Authentication Flow** - Connect to Google and Microsoft services
- 🔑 **API Key Management** - Add and validate SendGrid and Twilio credentials  
- 🛡️ **Secure Storage** - View encrypted credentials with AES-256-GCM
- 📊 **Credential Export** - Export all credentials to Google Sheets
- 🎯 **Real-time Validation** - Test connection status and token refresh

*The demo video shows the complete authentication flow and security features in action*

**📁 Video File**: `demo/AuthProject-Demo.mp4`

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

1. **Set Environment Variables in Xcode**
   - Open the project in Xcode
   - Select the **AuthProject** target
   - Go to **Product** → **Scheme** → **Edit Scheme**
   - Select **Run** on the left sidebar
   - Go to the **Arguments** tab
   - Under **Environment Variables**, click the **+** button and add:

   ```
   GOOGLE_CLIENT_ID = your-google-client-id.apps.googleusercontent.com
   MICROSOFT_CLIENT_ID = your-microsoft-client-id
   MICROSOFT_CLIENT_SECRET = your-microsoft-client-secret
   INSTAGRAM_CLIENT_ID = your-instagram-client-id
   INSTAGRAM_CLIENT_SECRET = your-instagram-app-secret
   TIKTOK_CLIENT_ID = your-tiktok-client-id
   TIKTOK_CLIENT_SECRET = your-tiktok-client-secret
   TWITTER_CLIENT_ID = your-twitter-client-id
   TWITTER_CLIENT_SECRET = your-twitter-client-secret
   SENDGRID_API_KEY = your-sendgrid-api-key
   TWILIO_API_KEY = your-twilio-api-key
   TWILIO_ACCOUNT_SID = your-twilio-account-sid
   ```

2. **OAuth Configuration**

## 🔧 **Step 1: Google OAuth Setup**

### **1.1 Create Google Cloud Project**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the APIs you need:
   - Google Calendar API
   - Google Sheets API
   - Google Drive API
   - Gmail API
   - **Google Sheets API** (for credential export functionality)

### **1.2 Configure OAuth Consent Screen**
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
   - `https://www.googleapis.com/auth/spreadsheets` (for credential export)

### **1.3 Create OAuth 2.0 Credentials**
1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth 2.0 Client IDs"
3. **Choose "iOS" as application type** (not Web)
4. Add your bundle identifier: `com.playground.AuthProject`
5. Copy the Client ID

### **1.4 Update Configuration**
1. Add the Google Client ID to your Xcode environment variables
2. The app uses Google Sign-In SDK which handles OAuth automatically
3. No need to configure redirect URIs manually

## 🔧 **Step 2: Microsoft OAuth Setup**

### **2.1 Create Azure App Registration**
1. Go to [Azure Portal](https://portal.azure.com/)
2. Navigate to "Azure Active Directory" → "App registrations"
3. Click "New registration"
4. Fill in details:
   - Name: "AuthProject"
   - **Supported account types: "Accounts in any organizational directory and personal Microsoft accounts"**
   - Redirect URI: `authproject://oauth/callback`

### **2.2 Configure API Permissions**
1. Go to "API permissions"
2. Add permissions:
   - Microsoft Graph → Calendars.ReadWrite
   - Microsoft Graph → Mail.ReadWrite
   - Microsoft Graph → Files.ReadWrite
3. Grant admin consent

### **2.3 Get Client Credentials**
1. Go to "Certificates & secrets"
2. Create a new client secret
3. Copy the Application (client) ID and Client Secret Value (not the ID)

### **2.4 Update Configuration**
Add the Microsoft credentials to your Xcode environment variables:

```
MICROSOFT_CLIENT_ID = your-actual-microsoft-client-id
MICROSOFT_CLIENT_SECRET = your-actual-microsoft-client-secret-value
```

## 🔧 **Step 3: Instagram OAuth Setup**

**⚠️ Note: Instagram OAuth is temporarily disabled due to Facebook OAuth redirect URI issues. We're working on a different approach.**

### **3.1 Create Instagram App**
1. Go to [Instagram Developer Portal](https://developers.facebook.com/apps/)
2. Click "Add New App" or select an existing app
3. **Important**: Choose **"Business"** app type (Instagram integration requires Business app type)
4. Fill in details:
   - App name: "AuthProject"
   - Contact email: your email address
   - Business account (required for Instagram integration)

### **3.2 Configure Instagram Graph API**
1. In your Facebook app dashboard, you should now see **"Add products to your app"** section
2. Look for **"Instagram Graph API"** in the available products
3. Click **"Set up"** next to Instagram Graph API
4. You should see the Instagram API setup page with:
   - Instagram app name: "AuthProject-IG"
   - Instagram app ID: (your app ID)
   - Instagram app secret: (your app secret)

### **3.3 Set up Instagram Business Login**
1. In the Instagram API setup page, scroll down to **"3. Set up Instagram business login"**
2. Click on this section to configure OAuth
3. Look for **"Valid OAuth Redirect URIs"** or **"Client OAuth Settings"**
4. Add these redirect URIs:
   - `authproject://oauth/callback`
   - `com.playground.AuthProject://oauth/callback`
5. **Important**: Also configure Facebook Login settings:
   - Go back to your main app dashboard
   - Look for **"Facebook Login"** in the left sidebar or in the "Add products to your app" section
   - Click **"Set up"** next to Facebook Login if it's not already set up
   - Go to **"Facebook Login"** → **"Settings"**
   - Add this redirect URI in the **"Valid OAuth Redirect URIs"** field:
     - `authproject://oauth/callback`
   - **Note**: Using bundle identifier scheme to avoid web page loading entirely
6. Save the configuration

**Note**: Instagram Graph API uses Facebook's OAuth endpoints, so you need to configure redirect URIs in both Instagram and Facebook Login settings.

### **3.4 Get Client Credentials**
1. **Important**: Instagram Graph API requires a **Facebook App ID**, not an Instagram App ID
2. Go to **"App Settings"** → **"Basic"** in your Facebook app
3. Copy the **App ID** (this is your Facebook App ID for Instagram Graph API)
4. Go back to the Instagram API setup page
5. Copy the **Instagram app secret** (click to reveal)
6. **Note**: The Instagram app ID shown in the Instagram API page is for Instagram-specific features, but OAuth uses the Facebook App ID

### **3.5 Update Configuration**
Add the Instagram credentials to your Xcode environment variables:

```
INSTAGRAM_CLIENT_ID = your-facebook-app-id-from-app-settings
INSTAGRAM_CLIENT_SECRET = your-instagram-app-secret
```

## 🔧 **Step 4: TikTok OAuth Setup**

### **4.1 Create TikTok App**
1. Go to [TikTok for Developers](https://developers.tiktok.com/)
2. Sign in with your TikTok account
3. **Look for "My Apps" or "Developer Dashboard"** in the top navigation
4. **Click "Create App"** or **"Add App"** button (usually in the top right or center of the dashboard)
5. If you don't see a create button, look for:
   - **"Get Started"** button
   - **"Create Your First App"** link
   - **"Add New App"** option in a dropdown menu
6. Fill in app details:
   - App name: "AuthProject"
   - App description: "Integration Authentication Platform"
   - Platform: "Web App"
   - Category: "Other"
   - **Terms of Service URL**: You need your own company terms of service URL
   - **Privacy Policy URL**: You need your own company privacy policy URL
   - **Note**: TikTok requires you to own the domains for these URLs and may require verification file uploads

### **4.2 Configure OAuth Settings**
1. In your TikTok app dashboard, go to **"App Management"** → **"OAuth"**
2. Add these redirect URIs:
   - `https://localhost/oauth/callback`
   - `http://localhost/oauth/callback`
3. Save the configuration

### **4.3 Get Client Credentials**
1. Go to **"App Management"** → **"Basic Info"**
2. Copy the **Client Key** (this is your Client ID)
3. Copy the **Client Secret**
4. **Note**: Keep these credentials secure

### **4.4 Update Configuration**
Add the TikTok credentials to your Xcode environment variables:

```
TIKTOK_CLIENT_ID = your-actual-tiktok-client-key
TIKTOK_CLIENT_SECRET = your-actual-tiktok-client-secret
```

## 🔧 **Step 5: X (Twitter) OAuth Setup**

### **5.1 Create Twitter App**
1. Go to [Twitter Developer Portal](https://developer.twitter.com/en/portal/dashboard)
2. Create a new app or select an existing one
3. Go to **"App Settings"** → **"User authentication settings"**
4. Enable **"OAuth 2.0"**
5. Set **"App permissions"** to **"Read and Write"**
6. **Add this callback URL**:
   ```
   authproject://oauth/callback
   ```

### **5.2 Get Client Credentials**
1. Go to **"Keys and tokens"** tab
2. Copy the **OAuth 2.0 Client ID**
3. Copy the **OAuth 2.0 Client Secret**
4. **Note**: Keep these credentials secure

### **5.3 Update Configuration**
Add the Twitter credentials to your Xcode environment variables:

```
TWITTER_CLIENT_ID = your-actual-twitter-client-id
TWITTER_CLIENT_SECRET = your-actual-twitter-client-secret
```

## 🔧 **Step 6: Twilio Setup**

### **6.1 Create Twilio Account**
1. Go to [Twilio Console](https://console.twilio.com/)
2. Sign up for a free account or sign in to existing account
3. Navigate to **"Console"** → **"Dashboard"**

### **6.2 Get Account Credentials**
1. In your Twilio Console dashboard, you'll see:
   - **Account SID**: Starts with "AC" (e.g., `AC...`)
   - **Auth Token**: Click "Show" to reveal (e.g., `...`)
2. **Copy both values** - you'll need them for the app

### **6.3 Update Configuration**
Add the Twilio credentials to your Xcode environment variables:

```
TWILIO_ACCOUNT_SID = your-actual-account-sid
TWILIO_AUTH_TOKEN = your-actual-auth-token
```

### **6.4 Using Twilio in the App**
1. In the app, tap **"Connect"** for Twilio
2. Enter your credentials in this format:
   ```
   AccountSID:AuthToken
   ```
   (Your Account SID followed by a colon, then your Auth Token)
3. The app will validate your credentials by making a real API call to Twilio
4. If successful, you'll see your account name and credentials will be stored securely

### **6.5 Twilio API Validation**
The app validates your Twilio credentials by:
- ✅ **Format validation**: Ensures Account SID starts with "AC" and has correct length
- ✅ **API call**: Makes a real request to Twilio's API to verify credentials
- ✅ **Account details**: Retrieves and stores your account name
- ✅ **Secure storage**: Encrypts and stores credentials locally

**Note**: The app uses Twilio's REST API to validate credentials, so you need an internet connection for authentication.

## 🔧 **Step 7: SendGrid Setup**

### **7.1 Create SendGrid Account**
1. Go to [SendGrid Dashboard](https://app.sendgrid.com/)
2. Sign up for a free account or sign in to existing account
3. Navigate to **"Settings"** → **"API Keys"**

### **7.2 Create API Key**
1. Click **"Create API Key"**
2. Choose **"Full Access"** or **"Restricted Access"** (Full Access recommended for testing)
3. Give your API key a name (e.g., "AuthProject")
4. Click **"Create & View"**
5. **Copy the API key** - it will look like: `SG.xxxxxxxxxxxxxxxxxxxxx.xxxxxxxxxxxxxxxxxxxxx`
6. **Important**: This is the only time you'll see the full API key, so copy it immediately

### **7.3 Using SendGrid in the App**
1. In the app, tap **"Connect"** for SendGrid
2. Enter your API key (the full key starting with "SG.")
3. The app will validate your credentials by making a real API call to SendGrid
4. If successful, you'll see your email address and credentials will be stored securely

### **7.4 SendGrid API Validation**
The app validates your SendGrid credentials by:
- ✅ **Format validation**: Ensures API key starts with "SG." and has correct length
- ✅ **API call**: Makes a real request to SendGrid's API to verify credentials
- ✅ **User details**: Retrieves and stores your email address
- ✅ **Secure storage**: Encrypts and stores credentials locally

**Note**: The app uses SendGrid's REST API to validate credentials, so you need an internet connection for authentication.

## Security Implementation

### Storage Architecture
- **Sensitive Data**: OAuth tokens, API keys stored directly in iOS Keychain
- **Non-sensitive Data**: Service metadata stored in UserDefaults
- **Encryption**: AES-256-GCM with unique IVs per credential
- **Key Management**: Automatic generation and storage in Keychain

### Environment Variables
- Client IDs and secrets loaded from Xcode scheme environment variables
- No hardcoded secrets in source code
- Secure credential management for development and production
