//
//  Find_and_ConnectApp.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/1/30.
//

import SwiftUI

@main
struct Find_and_ConnectApp: App {
    
    let appVersion = "1.3" // App version for version control
    
    var body: some Scene {
        WindowGroup {
            SplashView(appVersion: appVersion)
        }
    }
}
