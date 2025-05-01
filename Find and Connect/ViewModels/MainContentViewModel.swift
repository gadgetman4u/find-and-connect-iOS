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
    @Published var email: String
    
    // MARK: - Bluetooth Content Properties
    @Published var showingHeardLog = false
    @Published var showingTellLog = false
    @Published var showingHeardActions = false
    @Published var showingTellActions = false
    
    @Published var uploadResponse: UploadResponse?
    @Published var showingEncountersView = false
    
    // Add new properties to track log uploads
    @Published var hasTellLogUploaded = false
    @Published var hasHeardLogUploaded = false
    @Published var isProcessingEncounters = false
    @Published var processEncountersMessage = ""
    @Published var showProcessEncountersAlert = false
    @Published var processResponse: ProcessResponse?
    
    // Add a new property to store user encounter response
    @Published var userEncountersResponse: UserEncountersResponse?
    @Published var isLoadingEncounters = false
    @Published var showUserEncountersView = false
    @Published var encountersErrorMessage: String?
    
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
    
    // Add to properties section
    @Published var lastUploadedLogType: LogType = .tellLog
    
    // Add a computed property for trimmed username
    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Initialization
    init(beaconManager: BeaconScanManager, deviceManager: DeviceScanManager, peripheralManager: BluetoothPeripheralManager, username: String = "", email: String = "") {
        self.beaconManager = beaconManager
        self.deviceManager = deviceManager
        self.peripheralManager = peripheralManager
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines) // Trim on init
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines) // Trim on init
        
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
            lastUploadedLogType = isHeardSet ? .heardLog : .tellLog
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
                username: trimmedUsername,
                email: email,
                logType: logType
            )
            
            // Handle upload response
            await MainActor.run {
                self.uploadResponse = result
                self.isUploading = false
                
                // Set the appropriate flag based on which log was uploaded
                if isHeardSet {
                    self.hasHeardLogUploaded = true
                } else {
                    self.hasTellLogUploaded = true
                }
                
                // Show success message
                self.uploadMessage = "Upload successful: \(result.message)"
                self.showUploadAlert = true
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

    func processEncountersWithAPIManager() async {
        // Update UI to show loading
        await MainActor.run {
            isProcessingEncounters = true
        }
        
        do {
            // Process encounters using APIManager
            let result = try await APIManager.shared.processEncounters(for: trimmedUsername)
            
            // Handle success
            await MainActor.run {
                self.processResponse = result
                self.isProcessingEncounters = false
                
                // Show the result to the user
                if result.encountersDetected > 0 {
                    self.processEncountersMessage = "\(result.encountersDetected) encounters found. \(result.explanation)"
                    self.showProcessEncountersAlert = true
                } else {
                    self.processEncountersMessage = "No encounters found: \(result.message)"
                    self.showProcessEncountersAlert = true
                }
            }
        } catch {
            // Handle error
            await MainActor.run {
                isProcessingEncounters = false
                processEncountersMessage = "Processing failed: \(error.localizedDescription)"
                showProcessEncountersAlert = true
            }
        }
    }

    // Add a method to fetch user encounters
    func loadUserEncounters() {
        Task {
            await fetchUserEncounters(username: trimmedUsername)
        }
    }

    private func fetchUserEncounters(username: String) async {
        await MainActor.run {
            isLoadingEncounters = true
        }
        
        do {
            let response = try await APIManager.shared.getEncounters(for: username)
            
            await MainActor.run {
                self.userEncountersResponse = response
                self.isLoadingEncounters = false
                self.showUserEncountersView = true
            }
        } catch {
            print("⚠️ Error fetching encounters: \(error.localizedDescription)")
            
            await MainActor.run {
                // Create empty response with error message
                self.userEncountersResponse = UserEncountersResponse(
                    message: "Error: \(error.localizedDescription)",
                    encounters: [],
                    success: false
                )
                self.isLoadingEncounters = false
                self.showUserEncountersView = true
            }
        }
    }
} 
