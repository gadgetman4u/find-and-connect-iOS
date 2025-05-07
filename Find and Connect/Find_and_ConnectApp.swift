//
//  Find_and_ConnectApp.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/1/30.
//

import SwiftUI

@main
struct Find_and_ConnectApp: App {
    
    var appVersion: String {
        let dictionary = Bundle.main.infoDictionary!
        let version = dictionary["CFBundleShortVersionString"] as! String
        return "\(version)"
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView(appVersion: appVersion)
        }
    }
}
