import SwiftUI

struct CredentialsView: View {
    @ObservedObject var viewModel: IntegrationViewModel
    @State private var selectedService: ServiceMetadata?
    @State private var showingCredentialDetails = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showingExportSuccess = false
    @State private var exportedSheetId: String?
    
    private let storageService = StorageService.shared
    private let exportService = GoogleSheetsExportService.shared
    
    var body: some View {
        NavigationView {
            if viewModel.storedServices.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Connected Services")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Connect to services from the Dashboard to see your stored credentials here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .navigationTitle("Credentials")
            } else {
                VStack {
                    // Export Button
                    if !viewModel.storedServices.isEmpty {
                        Button(action: exportCredentials) {
                            HStack {
                                if isExporting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.white)
                                }
                                
                                Text(isExporting ? "Exporting..." : "Export to Google Sheets")
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isExporting ? Color.gray : Color.blue)
                            .cornerRadius(10)
                        }
                        .disabled(isExporting)
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    
                    // Credentials List
                    List {
                        ForEach(viewModel.storedServices) { service in
                            CredentialServiceCardView(service: service) {
                                selectedService = service
                                showingCredentialDetails = true
                            }
                        }
                    }
                }
                .navigationTitle("Credentials")
                .sheet(item: $selectedService) { service in
                    CredentialDetailView(service: service)
                }
                .alert("Export Error", isPresented: .constant(exportError != nil)) {
                    Button("OK") {
                        exportError = nil
                    }
                } message: {
                    Text(exportError ?? "")
                }
                .alert("Export Successful", isPresented: $showingExportSuccess) {
                    Button("Open in Google Sheets") {
                        if let sheetId = exportedSheetId {
                            openGoogleSheet(sheetId: sheetId)
                        }
                    }
                    Button("OK") {
                        showingExportSuccess = false
                        exportedSheetId = nil
                    }
                } message: {
                    Text("Your credentials have been exported to Google Sheets successfully!")
                }
            }
        }
    }
    
    private func exportCredentials() {
        guard !viewModel.storedServices.isEmpty else { return }
        
        isExporting = true
        exportError = nil
        
        Task {
            do {
                let sheetId = try await exportService.exportCredentialsToGoogleSheets()
                
                await MainActor.run {
                    isExporting = false
                    exportedSheetId = sheetId
                    showingExportSuccess = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }
    
    private func openGoogleSheet(sheetId: String) {
        let urlString = "https://docs.google.com/spreadsheets/d/\(sheetId)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

struct CredentialServiceCardView: View {
    let service: ServiceMetadata
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: getServiceIcon(for: service.serviceName))
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.serviceName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(service.authenticationType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: service.connectionStatus)
            }
            
            HStack {
                Text("Connected: \(service.createdAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
    
    private func getServiceIcon(for serviceName: String) -> String {
        if serviceName.contains("Google") { return "globe" }
        if serviceName.contains("Microsoft") || serviceName.contains("Office") { return "building.2" }
        if serviceName.contains("SendGrid") { return "envelope" }
        if serviceName.contains("Twilio") { return "message" }
        return "link"
    }
}

struct StatusBadge: View {
    let status: ConnectionStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .error:
            return .red
        case .disconnected:
            return .gray
        }
    }
}

struct CredentialDetailView: View {
    let service: ServiceMetadata
    @Environment(\.dismiss) private var dismiss
    @State private var credentials: Any?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let storageService = StorageService.shared
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    LoadingView()
                } else if let errorMessage = errorMessage {
                    ErrorView(errorMessage: errorMessage)
                } else {
                    CredentialContentView(credentials: credentials, service: service)
                }
            }
            .navigationTitle(service.serviceName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCredentials()
        }
    }
    
    private func loadCredentials() {
        Task {
            do {
                let result = try storageService.getCredentials(for: service.serviceName)
                await MainActor.run {
                    self.credentials = result.credentials
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("Loading credentials...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct ErrorView: View {
    let errorMessage: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error Loading Credentials")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct CredentialContentView: View {
    let credentials: Any?
    let service: ServiceMetadata
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ServiceInfoSection(service: service)
                
                // Display the decrypted credential data
                CredentialsSection(credentials: credentials)
                
                SecurityNoteSection()
            }
            .padding()
        }
    }
}

struct ServiceInfoSection: View {
    let service: ServiceMetadata
    @State private var storageData: EncryptedStorageData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Service Information")
                .font(.headline)
            
            InfoRow(title: "Service", value: service.serviceName)
            InfoRow(title: "Auth Type", value: service.authenticationType.rawValue.lowercased())
            
            // Encrypted Data
            if isLoading {
                InfoRow(title: "Encrypted Data", value: "Loading...")
                InfoRow(title: "IV", value: "Loading...")
            } else if let errorMessage = errorMessage {
                InfoRow(title: "Encrypted Data", value: "Error: \(errorMessage)")
                InfoRow(title: "IV", value: "Error: \(errorMessage)")
            } else if let storageData = storageData {
                InfoRow(title: "Encrypted Data", value: maskToken(storageData.encryptedData))
                InfoRow(title: "IV", value: maskToken(storageData.iv))
            }
            
            InfoRow(title: "Created At", value: service.createdAt, style: .date)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            loadStorageData()
        }
    }
    
    private func loadStorageData() {
        guard let storageJson = userDefaults.data(forKey: "credentials_\(service.serviceName)"),
              let storageData = try? JSONDecoder().decode(EncryptedStorageData.self, from: storageJson) else {
            self.errorMessage = "Storage data not found"
            self.isLoading = false
            return
        }
        
        self.storageData = storageData
        self.isLoading = false
    }
    
    private func maskToken(_ token: String) -> String {
        guard token.count > 8 else { return "***" }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)***\(suffix)"
    }
}

struct CredentialsSection: View {
    let credentials: Any?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Credentials")
                .font(.headline)
            
            if let credentials = credentials {
                if let oauthCredentials = credentials as? OAuthCredentials {
                    InfoRow(title: "Access Token", value: maskToken(oauthCredentials.accessToken))
                    if let refreshToken = oauthCredentials.refreshToken {
                        InfoRow(title: "Refresh Token", value: maskToken(refreshToken))
                    }
                    if let expiresAt = oauthCredentials.expiresAt {
                        InfoRow(title: "Expires At", value: expiresAt, style: .date)
                    }
                    if let scope = oauthCredentials.scope {
                        InfoRow(title: "Scope", value: scope)
                    }
                } else if let apiKeyCredentials = credentials as? APIKeyCredentials {
                    InfoRow(title: "API Key", value: maskToken(apiKeyCredentials.apiKey))
                    if let additionalData = apiKeyCredentials.additionalData, !additionalData.isEmpty {
                        ForEach(Array(additionalData.keys.sorted()), id: \.self) { key in
                            if let value = additionalData[key] {
                                InfoRow(title: key, value: value)
                            }
                        }
                    }
                }
            } else {
                Text("No credential data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func maskToken(_ token: String) -> String {
        guard token.count > 8 else { return "***" }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)***\(suffix)"
    }
}

struct SecurityNoteSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                Text("Security")
                    .font(.headline)
            }
            
            Text("All sensitive data is stored securely in the iOS Keychain and is not accessible to other apps.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let title: String
    let value: Any
    let style: InfoRowStyle
    
    init(title: String, value: Any, style: InfoRowStyle = .text) {
        self.title = title
        self.value = value
        self.style = style
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            switch style {
            case .text:
                Text("\(value as? String ?? "Unknown")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            case .date:
                if let date = value as? Date {
                    Text(date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Unknown")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

enum InfoRowStyle {
    case text
    case date
} 
