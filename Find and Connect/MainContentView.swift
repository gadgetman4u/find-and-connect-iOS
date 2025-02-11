import SwiftUI

struct MainContentView: View {
    @ObservedObject var bluetoothManager: BluetoothCentralManager
    @ObservedObject var peripheralManager: BluetoothPeripheralManager
    @Binding var isDeviceListExpanded: Bool
    @Binding var showingTellSetLog: Bool
    @Binding var showingHeardSetLog: Bool
    let username: String
    
    var body: some View {
        VStack(spacing: 15) {
            if bluetoothManager.isScanning {
                if !bluetoothManager.discoveredBeacons.isEmpty {
                    // Show current location info
                    Text("Current Location")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let locationId = bluetoothManager.nearestBeaconId {
                        Text(locationId)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    if let rssi = bluetoothManager.lastRSSI {
                        HStack {
                            Image(systemName: "wifi")
                            Text("Signal: \(rssi) dBm")
                        }
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        bluetoothManager.stopScanning()
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
                } else {
                    Text("Searching for rooms...")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
            } else {
                Button(action: {
                    bluetoothManager.startScanningBeacon()
                }) {
                    Text("Start Scanning")
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
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.15))
        )
        .padding()
        
        // Collapsible discovered devices list
        VStack {
            Button(action: {
                withAnimation {
                    isDeviceListExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Discovered Locations")
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
                    LazyVStack(spacing: 10) {
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
                .frame(maxHeight: 300)
            }
        }
        
    }
} 
