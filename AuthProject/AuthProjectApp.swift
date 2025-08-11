//
//  AuthProjectApp.swift
//  AuthProject
//
//  Created by Aravind Bilugu on 8/6/25.
//

import SwiftUI

@main
struct AuthProjectApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    // Configure Google Sign-In after the app is fully loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        GoogleSignInService.shared.configure()
                    }
                }
        }
    }
}
