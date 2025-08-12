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
                // For API key services, we need to prompt the user for their API key
                // This will be handled by the UI layer
                throw AuthenticationError.invalidAPIKey
            }
            
            await loadStoredServices()
            updateConnectionStatuses()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func connectWithAPIKey(_ service: IntegrationService, apiKey: String) async {
        print("🔗 Connecting to \(service.name) with API key...")
        print("🔍 Service details: name='\(service.name)', type=\(service.authenticationType)")
        isLoading = true
        errorMessage = nil
        
        do {
            let credentials = try await authenticationService.authenticateWithAPIKey(for: service, apiKey: apiKey)
            print("✅ API key validation successful for \(service.name)")
            try storageService.saveCredentials(for: service, credentials: credentials)
            print("💾 Credentials saved for \(service.name)")
            
            await loadStoredServices()
            updateConnectionStatuses()
            
        } catch let error as AuthenticationError {
            print("❌ Authentication error for \(service.name): \(error)")
            print("   Error description: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch {
            print("❌ Unexpected error for \(service.name): \(error)")
            print("   Error type: \(type(of: error))")
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