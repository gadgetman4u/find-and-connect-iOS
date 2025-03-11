import SwiftUI

struct MainContentView: View {
    @ObservedObject var bluetoothManager: BluetoothCentralManager
    @ObservedObject var peripheralManager: BluetoothPeripheralManager
    @Binding var isDeviceListExpanded: Bool
    @Binding var showingTellSetLog: Bool
    @Binding var showingHeardSetLog: Bool
    let username: String
    
    @State private var isViewLoaded = false
    @State private var isShareSheetPresented = false
    @State private var shareContent = ""
    
    var body: some View {
        VStack {
            VStack(spacing: 15) {
                if isViewLoaded {
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
                    
                    // Add share buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            shareTellLog()
                        }) {
                            Label("Share Tell Log", systemImage: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.blue.opacity(0.3))
                                )
                        }
                        
                        Button(action: {
                            shareHeardLog()
                        }) {
                            Label("Share Heard Log", systemImage: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.purple.opacity(0.3))
                                )
                        }
                    }
                    .padding(.horizontal)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .padding()
                    Text("Preparing...")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.15))
            )
            .padding()
            
            if isViewLoaded {
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
        // Add the share sheet at the end of the main VStack
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(activityItems: [shareContent])
        }
        // Add alert for version info
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isViewLoaded = true
            }
        }
    }
    
    private func shareHeardLog() {
        // Create a TextItemSource with filename
        let logContent = getHeardSetLog()
        shareContent = logContent
        isShareSheetPresented = true
    }
    
    private func shareTellLog() {
        // Create a TextItemSource with filename
        let logContent = getTellSetLog()
        shareContent = logContent
        isShareSheetPresented = true
    }
    
    private func getHeardSetLog() -> String {
        // Call the method properly with parentheses
        return bluetoothManager.getHeardLog()
    }
    
    private func getTellSetLog() -> String {
        // Call the method properly with parentheses
        return peripheralManager.getTellLog()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
