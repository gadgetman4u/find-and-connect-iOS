import SwiftUI

struct DiscoveredDevicesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var bluetoothManager: BluetoothCentralManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                if bluetoothManager.discoveredDevices.isEmpty {
                    Text("No devices discovered")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(bluetoothManager.discoveredDevices.indices, id: \.self) { index in
                                let device = bluetoothManager.discoveredDevices[index]
                                DeviceRow(device: device)
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                }
            }
            .padding()
            .navigationTitle("Discovered Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: HeardSetEntry
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(device.location)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "wifi")
                    .font(.system(size: 12))
                Text("\(device.rssi.intValue)")
                    .font(.system(size: 12, design: .monospaced))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
        )
        .padding(.horizontal)
    }
} 
