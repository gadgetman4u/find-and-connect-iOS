import SwiftUI

// MARK: - Main View
struct BluetoothContentView: View {
    @ObservedObject var viewModel: MainContentViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Status bar
            statusBar
            
            // Log monitoring status section
            monitoringStatusSection
            
            Spacer()
        }
        .overlay(loadingOverlay)
        .alert(isPresented: $viewModel.showingAlert) {
            Alert(title: Text("Bluetooth"), 
                  message: Text(viewModel.alertMessage), 
                  dismissButton: .default(Text("OK")))
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShareContent"))) { notification in
            if let content = notification.userInfo?["content"] as? String {
                let av = UIActivityViewController(activityItems: [content], applicationActivities: nil)
                UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - View Components
    
    private var statusBar: some View {
        HStack {
            Text("Status: \(viewModel.statusText)")
                .foregroundColor(viewModel.isScanning ? .green : .red)
            
            Spacer()
            
            Button(action: viewModel.toggleScanning) {
                Text(viewModel.isScanning ? "Stop" : "Start")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(viewModel.isScanning ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    // New monitoring status section that replaces the buttons
    private var monitoringStatusSection: some View {
        VStack(spacing: 15) {
            Text("Bluetooth Monitoring")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 15) {
                // HeardSet Status Card
                VStack(alignment: .leading, spacing: 4) {
                    Label("HeardSet", systemImage: "headphones")
                        .font(.system(size: 16, weight: .medium))
                    Text(viewModel.isScanning ? "Monitoring" : "Idle")
                        .font(.system(size: 14))
                        .foregroundColor(viewModel.isScanning ? .green : .gray)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                
                // TellSet Status Card
                VStack(alignment: .leading, spacing: 4) {
                    Label("TellSet", systemImage: "megaphone")
                        .font(.system(size: 16, weight: .medium))
                    Text(viewModel.isScanning ? "Broadcasting" : "Idle")
                        .font(.system(size: 14))
                        .foregroundColor(viewModel.isScanning ? .green : .gray)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private var loadingOverlay: some View {
        Group {
            if viewModel.isUploading {
                ProgressView("Processing...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                    .shadow(radius: 10)
            } else {
                EmptyView()
            }
        }
    }
}

// Preview for SwiftUI canvas
struct BluetoothContentView_Previews: PreviewProvider {
    static var previews: some View {
        BluetoothContentView(viewModel: MainContentViewModel(
            beaconManager: BeaconScanManager(),
            deviceManager: DeviceScanManager(),
            peripheralManager: BluetoothPeripheralManager()
        ))
    }
} 
