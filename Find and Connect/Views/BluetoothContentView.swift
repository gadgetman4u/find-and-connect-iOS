import SwiftUI

struct BluetoothContentView: View {
    @ObservedObject var bluetoothManager: BluetoothCentralManager
    @Binding var isDeviceListExpanded: Bool
    
    var body: some View {
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
