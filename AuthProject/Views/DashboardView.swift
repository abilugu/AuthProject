import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: IntegrationViewModel
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.services) { service in
                        ServiceCardView(service: service) {
                            Task {
                                await viewModel.connectToService(service)
                            }
                        } onDisconnect: {
                            viewModel.disconnectFromService(service)
                        } onConnectWithAPIKey: { apiKey in
                            await viewModel.connectWithAPIKey(service, apiKey: apiKey)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Integration Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.refreshConnectionStatuses()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { 
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                } else {
                    Text("An unknown error occurred")
                }
            }
        }
    }
}

struct ServiceCardView: View {
    let service: IntegrationService
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onConnectWithAPIKey: (String) async -> Void
    
    @State private var showingAPIKeyInput = false {
        didSet {
            if showingAPIKeyInput {
                print("📱 API key input sheet shown for \(service.name)")
            }
        }
    }
    @State private var apiKey = ""
    
    var body: some View {
        VStack(spacing: 12) {
            // Service Icon and Name
            VStack(spacing: 8) {
                Image(systemName: service.icon)
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                
                Text(service.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            // Authentication Type
            Text(service.authenticationType.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
            
            // Connection Status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(service.connectionStatus.displayName)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            // Action Button
            Button(action: {
                print("🔘 Button clicked for \(service.name)")
                if service.connectionStatus == .connected {
                    print("🔄 Disconnecting from \(service.name)")
                    onDisconnect()
                } else {
                    if service.authenticationType == .apiKey {
                        print("🔑 Showing API key input for \(service.name)")
                        showingAPIKeyInput = true
                    } else {
                        print("🔐 Starting OAuth for \(service.name)")
                        onConnect()
                    }
                }
            }) {
                Text(service.connectionStatus == .connected ? "Disconnect" : "Connect")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(service.connectionStatus == .connected ? .red : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(service.connectionStatus == .connected ? Color.red.opacity(0.1) : Color.blue)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .sheet(isPresented: $showingAPIKeyInput) {
            APIKeyInputView(
                serviceName: service.name,
                apiKey: $apiKey,
                onConnect: {
                    print("🔗 Connect button pressed in sheet")
                    print("📝 API Key entered: \(apiKey.prefix(8))...")
                    print("📝 Full API key length: \(apiKey.count)")
                    print("📝 API key contains whitespace: \(apiKey.contains(" "))")
                    print("📝 API key contains newlines: \(apiKey.contains("\n"))")
                    if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        print("✅ API key not empty, calling onConnectWithAPIKey")
                        // Capture the API key before clearing it
                        let capturedApiKey = apiKey
                        Task {
                            await onConnectWithAPIKey(capturedApiKey)
                        }
                        apiKey = ""
                        showingAPIKeyInput = false
                    } else {
                        print("❌ API key is empty after trimming")
                    }
                },
                onCancel: {
                    print("❌ Cancel button pressed in sheet")
                    apiKey = ""
                    showingAPIKeyInput = false
                }
            )
        }
    }
    
    private var statusColor: Color {
        switch service.connectionStatus {
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

struct APIKeyInputView: View {
    let serviceName: String
    @Binding var apiKey: String
    let onConnect: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Connect to \(serviceName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Please enter your \(serviceName) API key:")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                TextField("API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.red)
                    
                    Button("Connect") {
                        onConnect()
                    }
                    .foregroundColor(.blue)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

//#Preview {
//    DashboardView()
//} 
