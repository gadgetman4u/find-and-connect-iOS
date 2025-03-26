import SwiftUI

struct MainContentView: View {
    @ObservedObject var beaconManager: BeaconScanManager
    @ObservedObject var deviceManager: DeviceScanManager
    @ObservedObject var peripheralManager: BluetoothPeripheralManager
    @State private var showingLocationSheet = false
    @Binding var isDeviceListExpanded: Bool
    @Binding var showingTellSetLog: Bool
    @Binding var showingHeardSetLog: Bool
    let username: String
    
    @State private var isViewLoaded = false
    @State private var isShareSheetPresented = false
    @State private var shareContent = ""
    
    var body: some View {
        VStack(spacing: 20) {
            if isViewLoaded {
                locationInfoSection
                
                Button(action: {
                    showingLocationSheet = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("View Discovered Locations (\(beaconManager.discoveredBeacons.count))")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.white.opacity(0.2))
                    )
                    .padding(.horizontal)
                }
                
                shareButtonsSection
                
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
        .sheet(isPresented: $showingLocationSheet) {
            LocationsSheetView(beaconManager: beaconManager)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(activityItems: [shareContent])
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isViewLoaded = true
            }
        }
    }
    
    // MARK: - UI Components
    
    private var locationInfoSection: some View {
        VStack(spacing: 15) {
            if beaconManager.isScanning {
                if !beaconManager.discoveredBeacons.isEmpty {
                    // Show current location info
                    Text("Current Location")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let locationId = beaconManager.nearestBeaconId {
                        Text(locationId)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    if let rssi = beaconManager.lastRSSI {
                        HStack {
                            Image(systemName: "wifi")
                            Text("Signal: \(rssi) dBm")
                        }
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        beaconManager.stopScanning()
                        deviceManager.stopScanning()
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
                    beaconManager.startScanning()
                    deviceManager.startScanning()
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
    }
    
    private var shareButtonsSection: some View {
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
    }
    
    // MARK: - Helper Methods
    
    private func shareHeardLog() {
        let logContent = getHeardSetLog()
        shareContent = logContent
        isShareSheetPresented = true
    }
    
    private func shareTellLog() {
        let logContent = getTellSetLog()
        shareContent = logContent
        isShareSheetPresented = true
    }
    
    private func getHeardSetLog() -> String {
        return deviceManager.getHeardLog()
    }
    
    private func getTellSetLog() -> String {
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
