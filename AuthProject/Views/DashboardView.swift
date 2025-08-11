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
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        }
    }
}

struct ServiceCardView: View {
    let service: IntegrationService
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
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
                if service.connectionStatus == .connected {
                    onDisconnect()
                } else {
                    onConnect()
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
            .disabled(service.connectionStatus == .connecting)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var statusColor: Color {
        switch service.connectionStatus {
        case .connected:
            return .green
        case .disconnected:
            return .red
        case .connecting:
            return .orange
        case .error:
            return .red
        }
    }
}

//#Preview {
//    DashboardView()
//} 
