import Foundation
import CoreBluetooth

class BeaconScanManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var isBluetoothOn = false
    @Published var lastRSSI: NSNumber?
    @Published var nearestBeaconId: String?
    @Published var discoveredBeacons: [String] = []
    @Published var isScanning = false
    @Published var currentLocationId: String = ""
    
    // Store RSSI values for each beacon
    @Published var beaconRSSIMap: [String: NSNumber] = [:]
    
    // Track beacons with last seen timestamps
    private var beaconLastSeen: [String: Date] = [:]
    private var scanTimer: Timer?
    private let beaconTimeoutInterval: TimeInterval = 20.0 // Allow more time before timeout
    
    // Forward mapping (name to ID)
    private let locationToIDMap: [String: String] = [
        "Poster_1": "1",
        "Poster_2": "2",
        "Poster_3": "3",
        "Poster_4": "4",
        "Poster_5": "5"
    ]
    
    // Reverse mapping (ID to name)
    private lazy var idToLocationMap: [String: String] = {
        var reversed: [String: String] = [:]
        for (name, id) in locationToIDMap {
            reversed[id] = name
        }
        return reversed
    }()
    
    private var centralManager: CBCentralManager!
    private let beaconUUID = CBUUID(string: "00002080-0000-1000-8000-00805f9b34fb") // For finding beacons
    
    // Property to hold the username
    private var currentUsername: String = ""
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Helper Methods
    
    func getLocationID(_ name: String) -> String? {
        return locationToIDMap[name]
    }
    
    func getLocationName(_ id: String) -> String? {
        return idToLocationMap[id]
    }
    
    // Get RSSI for a specific beacon
    func getRSSI(for beaconId: String) -> NSNumber? {
        return beaconRSSIMap[beaconId]
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                print("Beacon Scanner: Bluetooth is powered on")
                self.isBluetoothOn = true
                self.startScanning()
            case .poweredOff:
                print("Beacon Scanner: Bluetooth is powered off")
                self.isBluetoothOn = false
                self.beaconRSSIMap.removeAll()
                self.discoveredBeacons.removeAll()
                self.stopScanning()
            case .unsupported:
                print("Beacon Scanner: Bluetooth is unsupported")
                self.isBluetoothOn = false
            case .unauthorized:
                print("Beacon Scanner: Bluetooth is unauthorized")
                self.isBluetoothOn = false
            case .resetting:
                print("Beacon Scanner: Bluetooth is resetting")
            case .unknown:
                print("Beacon Scanner: Bluetooth state is unknown")
            @unknown default:
                print("Beacon Scanner: Bluetooth state is unknown")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Check if the peripheral has a local name
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            // We found a beacon!
            DispatchQueue.main.async {
                print("Beacon Scanner: Found beacon: \(localName), RSSI: \(RSSI)")
                
                // Update the last seen timestamp for this beacon
                self.beaconLastSeen[localName] = Date()
                
                // Add to beacon RSSI map
                self.beaconRSSIMap[localName] = RSSI
                
                // Add to discovered beacons if not already there
                if !self.discoveredBeacons.contains(localName) {
                    self.discoveredBeacons.append(localName)
                    print("Beacon Scanner: Added new beacon: \(localName)")
                }
                
                // Update the nearest beacon
                self.updateNearestBeacon()
            }
        }
    }
    
    // MARK: - Scanning Methods
    
    func startScanning() {
        guard isBluetoothOn else { return }
        
        print("Beacon Scanner: Starting scan...")
        isScanning = true
        
        centralManager.scanForPeripherals(
            withServices: [beaconUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        
        // Set up periodic check for disappeared beacons
        scanTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Check for beacons that haven't been seen recently
            self.checkBeaconTimeouts()
        }
    }
    
    private func checkBeaconTimeouts() {
        let currentTime = Date()
        var timeoutBeacons: [String] = []
        
        // Check each beacon's last seen time
        for (beaconId, lastSeen) in beaconLastSeen {
            let timeSinceLastSeen = currentTime.timeIntervalSince(lastSeen)
            if timeSinceLastSeen > beaconTimeoutInterval {
                timeoutBeacons.append(beaconId)
            }
        }
        
        if !timeoutBeacons.isEmpty {
            print("Beacon Scanner: Beacons timed out: \(timeoutBeacons)")
            
            DispatchQueue.main.async {
                // Remove timed-out beacons
                for beaconId in timeoutBeacons {
                    if let index = self.discoveredBeacons.firstIndex(of: beaconId) {
                        self.discoveredBeacons.remove(at: index)
                    }
                    self.beaconRSSIMap.removeValue(forKey: beaconId)
                    self.beaconLastSeen.removeValue(forKey: beaconId)
                }
                
                // Update nearest beacon if needed
                if timeoutBeacons.contains(self.nearestBeaconId ?? "") {
                    self.updateNearestBeacon()
                }
            }
        }
    }
    
    private func updateNearestBeacon() {
        if let strongestBeacon = beaconRSSIMap.max(by: { $0.value.intValue < $1.value.intValue }) {
            self.lastRSSI = strongestBeacon.value
            
            if self.nearestBeaconId != strongestBeacon.key {
                self.nearestBeaconId = strongestBeacon.key
                self.currentLocationId = strongestBeacon.key
                NotificationCenter.default.post(
                    name: Notification.Name("LocationChanged"),
                    object: nil,
                    userInfo: ["locationName": strongestBeacon.key]
                )
            }
        } else {
            // No beacons in range
            self.nearestBeaconId = nil
            self.currentLocationId = ""
            NotificationCenter.default.post(
                name: Notification.Name("OutOfRange"),
                object: nil
            )
        }
    }
    
    func stopScanning() {
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
        centralManager.stopScan()
        beaconRSSIMap.removeAll()
        beaconLastSeen.removeAll()
        discoveredBeacons.removeAll()
        nearestBeaconId = nil
        currentLocationId = ""
        
        // Notify that we're out of range
        NotificationCenter.default.post(
            name: Notification.Name("OutOfRange"),
            object: nil
        )
    }
    
    deinit {
        stopScanning()
    }
    
    // MARK: - User Management
    func setUsername(_ username: String) {
        self.currentUsername = username
        print("Beacon Scanner: Username set to \(username)")
    }
} 
