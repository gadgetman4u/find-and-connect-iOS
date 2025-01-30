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
    @StateObject private var bluetoothManager = BluetoothManager()
    
    var body: some View {
        ZStack {
            // Background color based on state
            (bluetoothManager.isPaired ? Color.green : Color.orange)
                .ignoresSafeArea()
            
            if !bluetoothManager.isBluetoothOn {
                // Bluetooth Off View
                VStack(spacing: 20) {
                    Image(systemName: "bluetooth.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    Text("Bluetooth is Off")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Please enable Bluetooth in Settings to continue")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        if let url = URL(string: "App-Prefs:root=Bluetooth"), 
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else {
                            // Fallback to general settings if the direct Bluetooth URL doesn't work
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                    }) {
                        Text("Open Settings")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                            )
                    }
                    .padding(.top, 10)
                }
            } else {
                VStack {
                    // Only show the status text when not pairing
                    if !bluetoothManager.isPairing {
                        Text(bluetoothManager.isPaired ? "Paired" : "Looking for Rooms...")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    if !bluetoothManager.isPaired && !bluetoothManager.isPairing {
                        // Show list of discovered devices
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(bluetoothManager.discoveredDevices, id: \.peripheral.identifier) { device in
                                    DeviceRow(device: device) {
                                        bluetoothManager.pair(with: device)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    
                    if bluetoothManager.isPairing {
                        // Create a parent VStack for the entire pairing view
                        VStack {
                            Spacer() // Push content to center
                            
                            // Center content VStack
                            VStack(spacing: 15) {
                                Text(bluetoothManager.pairingText)
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                ProgressView(value: bluetoothManager.pairingProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                    .frame(width: 200)
                            }
                            
                            Spacer() // Create space between center content and button
                            
                            // Cancel button at bottom
                            Button(action: {
                                bluetoothManager.cancelPairing()
                            }) {
                                Text("Cancel Pairing")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white)
                                    )
                            }
                        }
                        .padding()
                        .frame(maxHeight: .infinity) // Take up full height
                    }
                    
                    if bluetoothManager.isPaired {
                        VStack(spacing: 20) {
                            Text("Connected to: \(bluetoothManager.currentDeviceName ?? "")")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding()
                            
                            // Add a count of received data entries
                            Text("Received Data Count: \(bluetoothManager.receivedData.count)")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                            
                            // Display received data with more detail
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(Array(bluetoothManager.receivedData.keys), id: \.self) { key in
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text("Key: \(key)")
                                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                                .foregroundColor(.white)
                                            
                                            if let value = bluetoothManager.receivedData[key] {
                                                Text("Value: \(String(describing: value))")
                                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                                    .foregroundColor(.white.opacity(0.9))
                                            }
                                        }
                                        .padding()
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            Button(action: {
                                bluetoothManager.disconnect()
                            }) {
                                Text("Disconnect")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white)
                                    )
                            }
                        }
                    }
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
