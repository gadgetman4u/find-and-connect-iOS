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

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothCentralManager()
    @StateObject private var peripheralManager = BluetoothPeripheralManager()
    @State private var isDeviceListExpanded = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("username") private var username = ""
    
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
                        if bluetoothManager.isLocked {
                            // Locked mode UI
                            VStack(spacing: 15) {
                                Text("Locked on Beacon")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                if let rssi = bluetoothManager.lastRSSI {
                                    HStack {
                                        Image(systemName: "wifi")
                                        Text("Signal: \(rssi) dBm")
                                    }
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                }
                                
                                Button(action: {
                                    bluetoothManager.unlockBeacon()
                                    peripheralManager.stopAdvertising()
                                }) {
                                    Text("Stop")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 15)
                                                .fill(Color.red.opacity(0.3))
                                        )
                                        .padding(.horizontal)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.15))
                            )
                            .padding()
                        } else {
                            // Scanning status
                            HStack {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 24))
                                Text("Scanning for devices...")
                            }
                            .foregroundColor(.white)
                            .padding()
                            
                            // Nearest beacon info with Start button
                            if let locationId = bluetoothManager.nearestBeaconId {
                                VStack(spacing: 10) {
                                    Text("Nearest Device")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    
                                    Text(locationId)
                                        .font(.system(size: 16, design: .monospaced))
                                    
                                    if let rssi = bluetoothManager.lastRSSI {
                                        HStack {
                                            Image(systemName: "wifi")
                                            Text("Signal: \(rssi) dBm")
                                        }
                                        .font(.system(size: 14))
                                    }
                                    
                                    Button(action: {
                                        bluetoothManager.lockOnBeacon()
                                        // Start advertising with the current location
                                        if let locationName = bluetoothManager.nearestBeaconId {
                                            peripheralManager.startAdvertising(username: username, locationName: locationName)
                                        }
                                    }) {
                                        Text("Start")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 15)
                                                    .fill(Color.green.opacity(0.3))
                                            )
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.white.opacity(0.15))
                                )
                                .padding(.horizontal)
                            }
                            
                            // Collapsible discovered devices list
                            VStack {
                                Button(action: {
                                    withAnimation {
                                        isDeviceListExpanded.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text("Discovered Devices")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        Text("(\(bluetoothManager.discoveredBeacons.count))")
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                        Image(systemName: isDeviceListExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 15)
                                            .fill(Color.white.opacity(0.15))
                                    )
                                    .padding(.horizontal)
                                }
                                
                                if isDeviceListExpanded {
                                    ScrollView {
                                        LazyVStack(spacing: 10) { //Lazy VStack to save RAM
                                            ForEach(bluetoothManager.discoveredBeacons, id: \.self) { beacon in
                                                HStack {
                                                    Image(systemName: "wave.3.right")
                                                        .foregroundColor(.blue)
                                                    Text(beacon)
                                                        .font(.system(size: 14, design: .monospaced))
                                                    Spacer()
                                                    if beacon == bluetoothManager.nearestBeaconId {
                                                        Image(systemName: "star.fill")
                                                            .foregroundColor(.yellow)
                                                    }
                                                }
                                                .padding()
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.white.opacity(0.9))
                                                )
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: (name: String, peripheral: CBPeripheral)
    let onPairTapped: () -> Void
    
    var body: some View {
        HStack {
            Text(device.name)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Button(action: onPairTapped) {
                Text("Pair")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
        )
    }
}

#Preview {
    ContentView()
}
