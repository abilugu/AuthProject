//
//  AuthProjectApp.swift
//  AuthProject
//
//  Created by Aravind Bilugu on 8/6/25.
//

import SwiftUI

@main
struct AuthProjectApp: App {
    @StateObject private var urlHandler = URLHandler()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    // Configure Google Sign-In after the app is fully loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        GoogleSignInService.shared.configure()
                    }
                }
                .onOpenURL { url in
                    print("🔗 App received URL: \(url)")
                    urlHandler.handleURL(url)
                }
        }
    }
}

class URLHandler: ObservableObject {
    func handleURL(_ url: URL) {
        print("🔗 URLHandler: Processing URL: \(url)")
        
        // Check if this is an OAuth callback
        if url.scheme == "authproject" || url.scheme == "com.playground.AuthProject" {
            print("🔗 URLHandler: OAuth callback detected")
            
            // Extract authorization code from URL
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                print("🔗 URLHandler: Authorization code extracted: \(code.prefix(10))...")
                
                // The ASWebAuthenticationSession should handle this automatically
                // This is just for debugging
            } else {
                print("🔗 URLHandler: No authorization code found in URL")
            }
        }
    }
}
