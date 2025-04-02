import SwiftUI
import Combine

class MainContentViewModel: ObservableObject {
    // MARK: - Dependencies
    let beaconManager: BeaconScanManager
    let deviceManager: DeviceScanManager
    let peripheralManager: BluetoothPeripheralManager
    private let logModifierHeard = LogModifier(isHeardSet: true)
    private let logModifierTell = LogModifier(isHeardSet: false)
    
    // MARK: - Published Properties
    @Published var isViewLoaded = false
    @Published var isShareSheetPresented = false
    @Published var shareContent = ""
    @Published var isUploading = false
    @Published var uploadMessage = ""
    @Published var showUploadAlert = false
    @Published var showingTellShareOptions = false
    @Published var showingHeardShareOptions = false
    @Published var showingLocationSheet = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var username: String
    
    // MARK: - Bluetooth Content Properties
    @Published var showingHeardLog = false
    @Published var showingTellLog = false
    @Published var showingHeardActions = false
    @Published var showingTellActions = false
    
    // MARK: - Computed Properties
    var isScanning: Bool {
        beaconManager.isScanning
    }
    
    var nearestBeaconId: String? {
        beaconManager.nearestBeaconId
    }
    
    var lastRSSI: Int? {
        return beaconManager.lastRSSI?.intValue
    }
    
    var discoveredBeaconCount: Int {
        beaconManager.discoveredBeacons.count
    }
    
    var hasDiscoveredBeacons: Bool {
        !beaconManager.discoveredBeacons.isEmpty
    }
    
    var statusText: String {
        isScanning ? "Scanning" : "Idle"
    }
    
    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(beaconManager: BeaconScanManager, deviceManager: DeviceScanManager, peripheralManager: BluetoothPeripheralManager, username: String = "") {
        self.beaconManager = beaconManager
        self.deviceManager = deviceManager
        self.peripheralManager = peripheralManager
        self.username = username.isEmpty ? UserDefaults.standard.string(forKey: "username") ?? "" : username
        
        // Start initial load animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isViewLoaded = true
        }
        
        // Subscribe to beacon detection events
        setupBeaconObserver()
    }
    
    private func setupBeaconObserver() {
        // Listen for beacon detection changes for fast UI changes
        beaconManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Force our view model to notify its changes too
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Also listen to device manager changes
        deviceManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Bluetooth Control Methods
    
    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    func startScanning() {
        // Prevent multiple start attempts
        guard !isScanning else {
            print("Already scanning, ignoring start request")
            return
        }
        
        print("Starting scan sequence...")
        
        // First perform complete shutdown to ensure clean state
        beaconManager.stopScanning()
        deviceManager.stopScanning()
        
        // Force UI update with a temporary property
        objectWillChange.send()
        
        // Slight delay to allow CoreBluetooth to fully process the stop command
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Now start scanning with fresh state
            print("Delayed start initiated")
            self.beaconManager.startScanning()
            self.deviceManager.startScanning()
            
            // Force another UI refresh
            self.objectWillChange.send()
            
            print("Scanning started - BeaconManager scanning: \(self.beaconManager.isScanning)")
        }
    }
    
    func stopScanning() {
        // Prevent multiple stop attempts  
        guard isScanning else {
            print("Already stopped, ignoring stop request")
            return
        }
        
        print("Stopping scan sequence...")
        
        beaconManager.stopScanning()
        deviceManager.stopScanning()
        
        // Force UI update
        objectWillChange.send()
        
        print("Scanning stopped - BeaconManager scanning: \(beaconManager.isScanning)")
    }
    
    // MARK: - Action Toggle Methods
    
    func toggleHeardActions() {
        withAnimation {
            showingHeardActions.toggle()
            if showingHeardActions && showingTellActions {
                showingTellActions = false
            }
        }
    }
    
    func toggleTellActions() {
        withAnimation {
            showingTellActions.toggle()
            if showingTellActions && showingHeardActions {
                showingHeardActions = false
            }
        }
    }
    
    // MARK: - Log Access Methods
    
    func getHeardLogContents() -> String? {
        return deviceManager.heardSet.readLogFile()
    }
    
    func getTellLogContents() -> String? {
        return peripheralManager.tellSet.readLogFile()
    }
    
    func clearHeardLog() {
        deviceManager.heardSet.clearLogFile()
    }
    
    func clearTellLog() {
        peripheralManager.tellSet.clearLogFile()
    }
    
    // MARK: - Sharing Methods
    
    func shareHeardLog() {
        guard let content = logModifierHeard.readLogFile() ?? deviceManager.heardSet.readLogFile() else {
            alertMessage = "No log content to share"
            showingAlert = true
            return
        }
        
        shareContent = content
        isShareSheetPresented = true
    }
    
    func shareTellLog() {
        guard let content = logModifierTell.readLogFile() ?? peripheralManager.tellSet.readLogFile() else {
            alertMessage = "No log content to share"
            showingAlert = true
            return
        }
        
        shareContent = content
        isShareSheetPresented = true
    }
    
    // MARK: - Upload Methods
    
    func uploadTellLogToServer() {
        Task {
            await uploadLogWithAPIManager(isHeardSet: false)
        }
    }
    
    func uploadHeardLogToServer() {
        Task {
            await uploadLogWithAPIManager(isHeardSet: true)
        }
    }
    
    private func uploadLogWithAPIManager(isHeardSet: Bool) async {
        // Update UI to show loading
        await MainActor.run {
            isUploading = true
        }
        
        do {
            // Get log content
            let logContent: String
            let logType: LogType = isHeardSet ? .heardLog : .tellLog
            
            if isHeardSet {
                logContent = deviceManager.getHeardLog()
            } else {
                logContent = peripheralManager.getTellLog()
            }
            
            // Upload using APIManager
            let result = try await APIManager.shared.uploadLog(
                logContent: logContent,
                username: username,
                logType: logType
            )
            
            // Handle success
            await MainActor.run {
                isUploading = false
                uploadMessage = "Upload successful: \(result)"
                showUploadAlert = true
            }
            
        } catch {
            // Handle error
            await MainActor.run {
                isUploading = false
                uploadMessage = "Upload failed: \(error.localizedDescription)"
                showUploadAlert = true
            }
        }
    }
} 
