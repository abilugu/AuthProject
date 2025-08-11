import Foundation
import GoogleSignIn

class GoogleSheetsExportService: ObservableObject {
    static let shared = GoogleSheetsExportService()
    
    private let storageService = StorageService.shared
    private let sheetsAPIBaseURL = "https://sheets.googleapis.com/v4/spreadsheets"
    
    private init() {}
    
    // MARK: - Export Credentials to Google Sheets
    
    func exportCredentialsToGoogleSheets() async throws -> String {
        // First, ensure user is signed in to Google with Sheets API scope
        let user = try await ensureGoogleSignInWithSheetsScope()
        
        // Get all stored services and their credentials
        let services = storageService.getAllStoredServices()
        guard !services.isEmpty else {
            throw ExportError.noCredentialsFound
        }
        
        var credentialsData: [[String: String]] = []
        
        for service in services {
            do {
                let (credentials, metadata) = try storageService.getCredentials(for: service.serviceName)
                
                // Get the encrypted storage data
                let userDefaults = UserDefaults.standard
                let storageJson = userDefaults.data(forKey: "credentials_\(service.serviceName)")
                let storageData = try? JSONDecoder().decode(EncryptedStorageData.self, from: storageJson ?? Data())
                
                var rowData: [String: String] = [
                    "Service Name": service.serviceName,
                    "Authentication Type": service.authenticationType.rawValue,
                    "Created At": formatDate(service.createdAt),
                    "Connection Status": service.connectionStatus.rawValue
                ]
                
                // Add encrypted storage data
                if let storageData = storageData {
                    rowData["Encrypted Data"] = storageData.encryptedData
                    rowData["IV"] = storageData.iv
                    rowData["Storage Created At"] = formatDate(storageData.createdAt)
                }
                
                // Add credential-specific data (actual values, not masked)
                if let oauthCredentials = credentials as? OAuthCredentials {
                    rowData["Access Token"] = oauthCredentials.accessToken
                    rowData["Refresh Token"] = oauthCredentials.refreshToken ?? "N/A"
                    rowData["Expires At"] = oauthCredentials.expiresAt != nil ? formatDate(oauthCredentials.expiresAt!) : "N/A"
                    rowData["Scope"] = oauthCredentials.scope ?? "N/A"
                } else if let apiKeyCredentials = credentials as? APIKeyCredentials {
                    rowData["API Key"] = apiKeyCredentials.apiKey
                    if let additionalData = apiKeyCredentials.additionalData {
                        for (key, value) in additionalData {
                            rowData[key] = value
                        }
                    }
                }
                
                credentialsData.append(rowData)
            } catch {
                // Add row with error information
                credentialsData.append([
                    "Service Name": service.serviceName,
                    "Authentication Type": service.authenticationType.rawValue,
                    "Created At": formatDate(service.createdAt),
                    "Connection Status": service.connectionStatus.rawValue,
                    "Error": "Failed to retrieve credentials"
                ])
            }
        }
        
        // Create a new Google Sheet
        let spreadsheetId = try await createNewSpreadsheet(user: user)
        
        // Export the data to the sheet
        try await exportDataToSheet(spreadsheetId: spreadsheetId, data: credentialsData, user: user)
        
        return spreadsheetId
    }
    
    // MARK: - Google Sign-In with Sheets Scope
    
    private func ensureGoogleSignInWithSheetsScope() async throws -> GIDGoogleUser {
        // Check if user is already signed in
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            // Check if user has the necessary scopes
            let scopes = currentUser.grantedScopes ?? []
            if scopes.contains("https://www.googleapis.com/auth/spreadsheets") {
                return currentUser
            }
        }
        
        // User needs to sign in with Sheets API scope
        return try await signInWithSheetsScope()
    }
    
    private func signInWithSheetsScope() async throws -> GIDGoogleUser {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    // Ensure we're on the main thread for UI operations
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let window = windowScene.windows.first,
                          let rootViewController = window.rootViewController else {
                        continuation.resume(throwing: ExportError.notSignedIn)
                        return
                    }
                    
                    // Get the topmost view controller
                    let topViewController = getTopViewController(from: rootViewController)
                    
                    // Sign in with additional scopes
                    let result = try await GIDSignIn.sharedInstance.signIn(
                        withPresenting: topViewController,
                        hint: nil,
                        additionalScopes: ["https://www.googleapis.com/auth/spreadsheets"]
                    )
                    
                    continuation.resume(returning: result.user)
                } catch {
                    print("Google Sign-In error: \(error)")
                    continuation.resume(throwing: ExportError.notSignedIn)
                }
            }
        }
    }
    
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
    
    // MARK: - Private Methods
    
    private func createNewSpreadsheet(user: GIDGoogleUser) async throws -> String {
        let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(user.accessToken.tokenString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let spreadsheetData: [String: Any] = [
            "properties": [
                "title": "AuthProject Credentials Backup - \(formatDate(Date())) - SENSITIVE DATA"
            ],
            "sheets": [
                [
                    "properties": [
                        "title": "Credentials",
                        "gridProperties": [
                            "rowCount": 1000,
                            "columnCount": 15
                        ]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: spreadsheetData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExportError.failedToCreateSpreadsheet
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Google Sheets API Error Response: \(errorResponse)")
            
            if httpResponse.statusCode == 401 {
                throw ExportError.notSignedIn
            } else if httpResponse.statusCode == 403 {
                throw ExportError.insufficientPermissions
            } else {
                throw ExportError.failedToCreateSpreadsheet
            }
        }
        
        let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let spreadsheetId = responseDict?["spreadsheetId"] as? String else {
            print("Failed to parse spreadsheet ID from response")
            throw ExportError.failedToCreateSpreadsheet
        }
        
        return spreadsheetId
    }
    
    private func exportDataToSheet(spreadsheetId: String, data: [[String: String]], user: GIDGoogleUser) async throws {
        guard !data.isEmpty else { return }
        
        // Get all unique keys to create headers
        let allKeys = Set(data.flatMap { $0.keys })
        let sortedKeys = Array(allKeys).sorted()
        
        // Create header row
        var rows: [[String]] = [sortedKeys]
        
        // Add data rows
        for rowData in data {
            var row: [String] = []
            for key in sortedKeys {
                row.append(rowData[key] ?? "")
            }
            rows.append(row)
        }
        
        // Prepare the update request
        let url = URL(string: "\(sheetsAPIBaseURL)/\(spreadsheetId)/values/A1:\(getColumnLetter(sortedKeys.count))\(rows.count)?valueInputOption=RAW")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(user.accessToken.tokenString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "values": rows
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExportError.failedToExportData
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func maskToken(_ token: String) -> String {
        guard token.count > 8 else { return "***" }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)***\(suffix)"
    }
    
    private func getColumnLetter(_ columnNumber: Int) -> String {
        var result = ""
        var num = columnNumber
        
        while num > 0 {
            num -= 1
            result = String(Character(UnicodeScalar(65 + (num % 26))!)) + result
            num /= 26
        }
        
        return result
    }
}

// MARK: - Export Errors

enum ExportError: Error, LocalizedError {
    case notSignedIn
    case failedToCreateSpreadsheet
    case failedToExportData
    case noCredentialsFound
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Please sign in to Google to export credentials"
        case .failedToCreateSpreadsheet:
            return "Failed to create Google Sheet"
        case .failedToExportData:
            return "Failed to export data to Google Sheet"
        case .noCredentialsFound:
            return "No credentials found to export"
        case .insufficientPermissions:
            return "Insufficient permissions to create Google Sheet. Please ensure Google Sheets API is enabled and you have the necessary permissions."
        }
    }
} 