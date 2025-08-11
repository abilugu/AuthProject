import Foundation
import SwiftUI

@MainActor
class IntegrationViewModel: ObservableObject {
    @Published var services: [IntegrationService] = []
    @Published var storedServices: [ServiceMetadata] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authenticationService = AuthenticationService.shared
    private let storageService = StorageService.shared
    
    init() {
        loadServices()
        Task {
            await loadStoredServices()
        }
    }
    
    func loadServices() {
        services = [
            // Google Services
            IntegrationService(name: "Google Calendar", icon: "calendar", authenticationType: .oauth),
            IntegrationService(name: "Google Sheets", icon: "tablecells", authenticationType: .oauth),
            IntegrationService(name: "Google Drive", icon: "folder", authenticationType: .oauth),
            IntegrationService(name: "Google Gmail", icon: "envelope", authenticationType: .oauth),
            
            // Microsoft Services
            IntegrationService(name: "Office 365 Calendar", icon: "calendar", authenticationType: .oauth),
            IntegrationService(name: "Office 365 Mail", icon: "envelope", authenticationType: .oauth),
            IntegrationService(name: "OneDrive", icon: "folder", authenticationType: .oauth),
            
            // Social Media Services
            IntegrationService(name: "Instagram", icon: "camera", authenticationType: .oauth),
            IntegrationService(name: "TikTok", icon: "video", authenticationType: .oauth),
            IntegrationService(name: "X (Twitter)", icon: "bird", authenticationType: .oauth),
            IntegrationService(name: "YouTube", icon: "play.rectangle", authenticationType: .oauth),
            IntegrationService(name: "Facebook", icon: "person.2", authenticationType: .oauth),
            IntegrationService(name: "LinkedIn", icon: "briefcase", authenticationType: .oauth),
            IntegrationService(name: "Snapchat", icon: "camera.viewfinder", authenticationType: .oauth),
            
            // API Key Services
            IntegrationService(name: "SendGrid", icon: "envelope", authenticationType: .apiKey),
            IntegrationService(name: "Twilio", icon: "message", authenticationType: .apiKey)
        ]
        
        updateConnectionStatuses()
    }
    
    func connectToService(_ service: IntegrationService) async {
        isLoading = true
        errorMessage = nil
        
        do {
            switch service.authenticationType {
            case .oauth:
                let credentials = try await authenticationService.authenticateWithOAuth(for: service)
                try storageService.saveCredentials(for: service, credentials: credentials)
                
            case .apiKey:
                // For demo purposes, generate a mock API key
                let mockApiKey = "sk_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
                let apiKeyCredentials = APIKeyCredentials(
                    apiKey: mockApiKey,
                    additionalData: [
                        "service": service.name,
                        "created_at": ISO8601DateFormatter().string(from: Date())
                    ]
                )
                try storageService.saveCredentials(for: service, credentials: apiKeyCredentials)
            }
            
            await loadStoredServices()
            updateConnectionStatuses()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func disconnectFromService(_ service: IntegrationService) {
        storageService.removeCredentials(for: service.name)
        updateConnectionStatuses()
        Task {
            await loadStoredServices()
        }
    }
    
    func loadStoredServices() async {
        storedServices = storageService.getAllStoredServices()
    }
    
    private func updateConnectionStatuses() {
        for i in 0..<services.count {
            services[i].connectionStatus = storageService.isServiceConnected(services[i].name) ? .connected : .disconnected
        }
    }
    
    func refreshConnectionStatuses() {
        updateConnectionStatuses()
    }
} 