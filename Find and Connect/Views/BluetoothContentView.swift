import SwiftUI

struct BluetoothContentView: View {
    @ObservedObject var bluetoothManager: BeaconScanManager
    @Binding var isDeviceListExpanded: Bool
    
    var body: some View {
        VStack(spacing: 15) {
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
                    LazyVStack(spacing: 15) {
                        ForEach(bluetoothManager.discoveredBeacons, id: \.self) { beacon in
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Image(systemName: "wave.3.right")
                                            .foregroundColor(.blue)
                                        Text(beacon)
                                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    }
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 15) {
                                    if let rssi = bluetoothManager.getRSSI(for: beacon) {
                                        HStack(spacing: 2) {
                                            Image(systemName: "wifi")
                                                .foregroundColor(.blue)
                                            Text("\(rssi) dBm")
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundColor(.blue)
                                        }
                                        .padding(6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.blue.opacity(0.1))
                                        )
                                    } else {
                                        Text("No RSSI")
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    if beacon == bluetoothManager.nearestBeaconId {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.9))
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .frame(maxHeight: 400)
                .padding(.bottom, 10)
            }
        }
    }
} 
