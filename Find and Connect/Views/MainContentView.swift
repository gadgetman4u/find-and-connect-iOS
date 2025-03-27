import SwiftUI

struct ExpandableActionButton: View {
    @Binding var isExpanded: Bool
    let primaryIcon: String
    let primaryAction: () -> Void
    let secondaryActions: [(icon: String, color: Color, action: () -> Void)]
    let baseColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Show secondary actions when expanded
            if isExpanded {
                ForEach(0..<secondaryActions.count, id: \.self) { index in
                    let action = secondaryActions[index]
                    Button(action: {
                        withAnimation(.spring()) {
                            self.isExpanded = false
                        }
                        action.action()
                    }) {
                        Image(systemName: action.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(action.color)
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Main button that toggles or performs primary action
            Button(action: {
                if secondaryActions.isEmpty {
                    primaryAction()
                } else {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }
            }) {
                Image(systemName: isExpanded ? "xmark" : primaryIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(baseColor)
                            .shadow(color: baseColor.opacity(0.3), radius: 5, x: 0, y: 2)
                    )
            }
        }
    }
}

struct MainContentView: View {
    @StateObject private var viewModel: MainContentViewModel
    @Binding var isDeviceListExpanded: Bool
    @Binding var showingTellSetLog: Bool
    @Binding var showingHeardSetLog: Bool
    
    // Initialize with dependencies and create the ViewModel
    init(beaconManager: BeaconScanManager, deviceManager: DeviceScanManager, peripheralManager: BluetoothPeripheralManager, isDeviceListExpanded: Binding<Bool>, showingTellSetLog: Binding<Bool>, showingHeardSetLog: Binding<Bool>, username: String) {
        self._isDeviceListExpanded = isDeviceListExpanded
        self._showingTellSetLog = showingTellSetLog
        self._showingHeardSetLog = showingHeardSetLog
        
        _viewModel = StateObject(wrappedValue: MainContentViewModel(
            beaconManager: beaconManager, 
            deviceManager: deviceManager, 
            peripheralManager: peripheralManager, 
            username: username
        ))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isViewLoaded {
                locationInfoSection
                
                Button(action: {
                    viewModel.showingLocationSheet = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("View Discovered Locations (\(viewModel.discoveredBeaconCount))")
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
                
                improvedShareButtonsSection
                
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
        .sheet(isPresented: $viewModel.showingLocationSheet) {
            LocationsSheetView(beaconManager: viewModel.beaconManager)
        }
        .sheet(isPresented: $viewModel.isShareSheetPresented) {
            ShareSheet(activityItems: [viewModel.shareContent])
        }
        .sheet(isPresented: $showingTellSetLog) {
            if let logContents = viewModel.getTellLogContents() {
                TellSetView(logContents: logContents, onClear: viewModel.clearTellLog)
            } else {
                TellSetView(logContents: "Error reading log file", onClear: viewModel.clearTellLog)
            }
        }
        .sheet(isPresented: $showingHeardSetLog) {
            if let logContents = viewModel.getHeardLogContents() {
                HeardSetView(logContents: logContents, onClear: viewModel.clearHeardLog)
            } else {
                HeardSetView(logContents: "Error reading log file", onClear: viewModel.clearHeardLog)
            }
        }
        .alert(isPresented: $viewModel.showUploadAlert) {
            Alert(
                title: Text("Log Upload"),
                message: Text(viewModel.uploadMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay(
            Group {
                if viewModel.isUploading {
                    ZStack {
                        Color.black.opacity(0.4)
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Uploading...")
                                .foregroundColor(.white)
                                .padding(.top, 10)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.7))
                        )
                    }
                    .ignoresSafeArea()
                }
            }
        )
    }
    
    // MARK: - UI Components
    
    private var locationInfoSection: some View {
        VStack(spacing: 15) {
            if viewModel.isScanning {
                if viewModel.hasDiscoveredBeacons {
                    // Show current location info
                    Text("Current Location")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let locationId = viewModel.nearestBeaconId {
                        Text(locationId)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    if let rssi = viewModel.lastRSSI {
                        HStack {
                            Image(systemName: "wifi")
                            Text("Signal: \(rssi) dBm")
                        }
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                    }
                    
                    Button(action: viewModel.stopScanning) {
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
                Button(action: viewModel.startScanning) {
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
    
    private var improvedShareButtonsSection: some View {
        VStack(spacing: 20) {
            // Tell Log Actions - Entire card is clickable
            Button(action: {
                showingTellSetLog = true
            }) {
                HStack {
                    Text("Tell Log")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // This prevents the expandable button from triggering the card tap
                    ExpandableActionButton(
                        isExpanded: $viewModel.showingTellShareOptions,
                        primaryIcon: "ellipsis",
                        primaryAction: { },
                        secondaryActions: [
                            (icon: "square.and.arrow.up", color: .blue, action: viewModel.shareTellLog),
                            (icon: "icloud.and.arrow.up", color: .green, action: viewModel.uploadTellLogToServer)
                        ],
                        baseColor: .green
                    )
                    .allowsHitTesting(true) // Ensure button gets taps
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .contentShape(Rectangle()) // Make entire area tappable
            }
            .buttonStyle(CardButtonStyle(color: .green))
            .padding(.horizontal)
            
            // Heard Log Actions - Entire card is clickable
            Button(action: {
                showingHeardSetLog = true
            }) {
                HStack {
                    Text("Heard Log")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // This prevents the expandable button from triggering the card tap
                    ExpandableActionButton(
                        isExpanded: $viewModel.showingHeardShareOptions,
                        primaryIcon: "ellipsis",
                        primaryAction: { },
                        secondaryActions: [
                            (icon: "square.and.arrow.up", color: .blue, action: viewModel.shareHeardLog),
                            (icon: "icloud.and.arrow.up", color: .purple, action: viewModel.uploadHeardLogToServer)
                        ],
                        baseColor: .blue
                    )
                    .allowsHitTesting(true) // Ensure button gets taps
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .contentShape(Rectangle()) // Make entire area tappable
            }
            .buttonStyle(CardButtonStyle(color: .blue))
            .padding(.horizontal)
        }
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

// Add this custom button style for better visual feedback
struct CardButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.25 : 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .strokeBorder(color.opacity(0.4), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

// Preview
struct MainContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainContentView(beaconManager: BeaconScanManager(), deviceManager: DeviceScanManager(), peripheralManager: BluetoothPeripheralManager(), isDeviceListExpanded: .constant(false), showingTellSetLog: .constant(false), showingHeardSetLog: .constant(false), username: "John Doe")
    }
}
