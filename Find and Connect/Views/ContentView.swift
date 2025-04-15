//
//  ContentView.swift
//  CursorTest
//
//  Created by Billy Huang on 2025/1/29.
//

import SwiftUI
import Foundation
import CoreBluetooth
import UIKit
import UserNotifications

struct ContentView: View {
    // Only keep non-Bluetooth state at the top level
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("username") private var username = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("email") private var email = ""
    let appVersion: String
    
    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView(isOnboardingCompleted: $hasCompletedOnboarding)
        } else if !isLoggedIn {
            LoginView(isLoggedIn: $isLoggedIn, username: $username, email: $email)
        } else {
            // Only initialize Bluetooth managers after login
            MainAppContent(username: username, email: email, appVersion: appVersion)
        }
    }
}

// New view to encapsulate the main app content after login
struct MainAppContent: View {
    // Initialize Bluetooth managers here - AFTER login
    @StateObject private var beaconManager = BeaconScanManager()
    @StateObject private var deviceManager = DeviceScanManager()
    @StateObject private var peripheralManager = BluetoothPeripheralManager()
    
    @State private var isDeviceListExpanded = false
    @State private var showingTellSetLog = false
    @State private var showingHeardSetLog = false
    @State private var showingVersionInfo = false
    @State private var showingHelpInfo = false
    
    let username: String
    let email: String
    let appVersion: String
    
    let center = UNUserNotificationCenter.current()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.blue.opacity(0.9)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header with username and logout button
                HStack {
                    Text("Hello, \(username)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        // Stop all Bluetooth activity before logging out
                        beaconManager.stopScanning()
                        deviceManager.stopScanning()
                        peripheralManager.stopAdvertising()
                        
                        // Update UserDefaults
                        UserDefaults.standard.removeObject(forKey: "username")
                        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 30)
                
                if !beaconManager.isBluetoothOn {
                    // Bluetooth disabled view
                    VStack(spacing: 15) {
                        Image(systemName: "bluetooth.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                        
                        Text("Please enable Bluetooth")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.white.opacity(0.15))
                    )
                } else {
                    MainContentView(
                        beaconManager: beaconManager,
                        deviceManager: deviceManager,
                        peripheralManager: peripheralManager,
                        isDeviceListExpanded: $isDeviceListExpanded,
                        showingTellSetLog: $showingTellSetLog,
                        showingHeardSetLog: $showingHeardSetLog,
                        username: username,
                        email: email
                    )
                }
                
                Spacer()
                
                HStack {
                    Button(action: {
                        showingHelpInfo = true
                    }) {
                        Text("More Info")
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    Button(action: {
                        showingVersionInfo = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                .padding(.horizontal)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LocationChanged"))) { notification in
            if let locationName = notification.userInfo?["locationName"] as? String {
                peripheralManager.startAdvertising(username: username, locationName: locationName)
                sendLocationChangeNotification(newLocation: locationName)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OutOfRange"))) { _ in
            peripheralManager.stopAdvertising()
            sendLocationChangeNotification(newLocation: "Out of range")
        }
        .onAppear {
            // Initialize managers with username ONLY after login
            beaconManager.setUsername(username)
            deviceManager.setUsername(username)
            
            // Start scanning here instead of automatically
            beaconManager.startScanning()
            deviceManager.startScanning()
            
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { success, error in
                if let error = error {
                    print("Notification permission error: \(error)")
                }
            }
        }
        .alert("App Version", isPresented: $showingVersionInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Find and Connect v\(appVersion)")
        }
        // Add this fullScreenCover to show the onboarding view when "More Info" is tapped
        .fullScreenCover(isPresented: $showingHelpInfo) {
            // Create a new binding for temporary use that doesn't affect the real onboarding completed state
            OnboardingViewForHelp(isPresented: $showingHelpInfo)
        }
    }
    
    func sendLocationChangeNotification(newLocation: String) {
        let content = UNMutableNotificationContent()
        content.title = "Location Changed"
        content.body = "You are now in \(newLocation)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
}

// Create a variant of OnboardingView that can be shown from "More Info" without affecting onboarding state
struct OnboardingViewForHelp: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.blue.opacity(0.9)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // Use the same pages and layout as OnboardingView
                TabView {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        OnboardingCardView(page: onboardingPages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                Button("Close") {
                    isPresented = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding()
                .padding(.horizontal, 50)
                .background(Color.white.opacity(0.3))
                .cornerRadius(20)
                .padding(.bottom, 30)
            }
        }
    }
    
    // Define onboarding pages
    private let onboardingPages: [OnboardingPage] = [
        OnboardingPage(
            image: "wave.3.right.circle.fill",
            title: "Welcome to Find & Connect",
            description: "This app helps you track and discover encounters with other users at specific locations."
        ),
        OnboardingPage(
            image: "headphones",
            title: "HeardSet Logs",
            description: "Your device listens for nearby users and records their presence in your HeardSet log."
        ),
        OnboardingPage(
            image: "megaphone",
            title: "TellSet Logs",
            description: "Your device broadcasts your presence, allowing others to discover you in specific locations. This is stored in the TellSet log"
        ),
        OnboardingPage(
            image: "person.2.fill",
            title: "Discover Encounters",
            description: "Upload your logs to see who you've encountered, when, and where."
        )
    ]
}

//#Preview {
//    ContentView()
//}
