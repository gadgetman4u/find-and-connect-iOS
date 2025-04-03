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
    @StateObject private var beaconManager = BeaconScanManager()
    @StateObject private var deviceManager = DeviceScanManager()
    @StateObject private var peripheralManager = BluetoothPeripheralManager()
    @State private var isDeviceListExpanded = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("username") private var username = ""
    @State private var showingTellSetLog = false
    @State private var showingHeardSetLog = false
    @State private var showingDiscoveredDevices = false
    @State private var showingVersionInfo = false
    let appVersion: String 
    
    let center = UNUserNotificationCenter.current()
    
    var body: some View {
        if !isLoggedIn {
            LoginView(isLoggedIn: $isLoggedIn, username: $username)
        } else {
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
                            isLoggedIn = false
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
                            username: username
                        )
                    }

                    Spacer()
                    
                    HStack {
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
                beaconManager.setUsername(username)
                deviceManager.setUsername(username)
                
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
    
    func showTellSetLogView() {
        showingTellSetLog = true
    }
}

//#Preview {
//    ContentView()
//}
