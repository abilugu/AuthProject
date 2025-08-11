import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = IntegrationViewModel()
    
    var body: some View {
        TabView {
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Dashboard")
                }
            
            CredentialsView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "lock.shield")
                    Text("Credentials")
                }
        }
        .onAppear {
            // Delay Google Sign-In configuration to ensure app is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                GoogleSignInService.shared.configure()
            }
        }
    }
}

#Preview {
    MainTabView()
} 