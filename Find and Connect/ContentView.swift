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
    @StateObject private var bluetoothManager = BluetoothCentralManager()
    @StateObject private var peripheralManager = BluetoothPeripheralManager()
    @State private var isDeviceListExpanded = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("username") private var username = ""
    @State private var showingTellSetLog = false
    @State private var showingHeardSetLog = false
    @State private var showingDiscoveredDevices = false
    
    let center = UNUserNotificationCenter.current()
    
    var body: some View {
        if !isLoggedIn {
            LoginView(isLoggedIn: $isLoggedIn, username: $username)
        } else {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.black.opacity(0.9)]),
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
                    
                    if !bluetoothManager.isBluetoothOn {
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
                            bluetoothManager: bluetoothManager,
                            peripheralManager: peripheralManager,
                            isDeviceListExpanded: $isDeviceListExpanded,
                            showingTellSetLog: $showingTellSetLog,
                            showingHeardSetLog: $showingHeardSetLog,
                            username: username
                        )
                    }
                    
                    
                    Button(action: {
                        showingTellSetLog = true
                    }) {
                        Text("View TellSet Log")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.blue.opacity(0.3))
                            )
                    }
                    .sheet(isPresented: $showingTellSetLog) {
                        if let logContents = peripheralManager.tellSet.readLogFile() {
                            TellSetView(logContents: logContents, onClear: {
                                peripheralManager.tellSet.clearLogFile()
                            })
                        } else {
                            TellSetView(logContents: "Error reading log file", onClear: {
                                peripheralManager.tellSet.clearLogFile()
                            })
                        }
                    }
                    
                    Button(action: {
                        showingHeardSetLog = true
                    }) {
                        Text("View HeardSet Log")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.purple.opacity(0.3))
                            )
                    }
                    .sheet(isPresented: $showingHeardSetLog) {
                        if let logContents = bluetoothManager.heardSet.readLogFile() {
                            HeardSetView(logContents: logContents, onClear: {
                                bluetoothManager.heardSet.clearLogFile()
                            })
                        } else {
                            HeardSetView(logContents: "Error reading log file", onClear: {
                                bluetoothManager.heardSet.clearLogFile()
                            })
                        }
                    }
                    Spacer()
                    
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

#Preview {
    ContentView()
}
