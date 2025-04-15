import Foundation
import CoreBluetooth

class DeviceScanManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var isBluetoothOn = false
    @Published var isScanning = false
    
    // Current location info - will be updated from notifications
    private var currentLocationId: String = ""
    private var currentUsername: String = ""
    
    // LogModifiers for heard logs
    var heardSet: LogModifier { _heardSet }
    private var _heardSet = LogModifier(isHeardSet: true)
    
    // Managers
    private var centralManager: CBCentralManager!
    
    // UUIDs
    private let serviceUUID = CBUUID(string: "09bda1b5-41fa-3620-a65b-de20ab32db77") // For finding other devices
    
    // For logging
    private var lastPrintTime: TimeInterval = 0
    private let printInterval: TimeInterval = 10.0  // 10 seconds interval
    
    // Forward mapping (name to ID)
    private let locationToIDMap: [String: String] = [
        "Poster_1": "1",
        "Poster_2": "2",
        "Poster_3": "3",
        "Poster_4": "4",
        "Poster_5": "5",
        "DPI_20_2049": "6"
    ]
    
    // Reverse mapping (ID to name)
    private lazy var idToLocationMap: [String: String] = {
        var reversed: [String: String] = [:]
        for (name, id) in locationToIDMap {
            reversed[id] = name
        }
        return reversed
    }()
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Listen for location changes from BeaconScanManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocationChanged(_:)),
            name: Notification.Name("LocationChanged"),
            object: nil
        )
        
        // Listen for out of range notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOutOfRange),
            name: Notification.Name("OutOfRange"),
            object: nil
        )
    }
    
    @objc private func handleLocationChanged(_ notification: Notification) {
        if let locationName = notification.userInfo?["locationName"] as? String {
            self.currentLocationId = locationName
            print("Device Scanner: Location changed to \(locationName)")
        }
    }
    
    @objc private func handleOutOfRange() {
        self.currentLocationId = ""
        print("Device Scanner: Out of range")
    }
    
    // MARK: - Helper Methods
    func getLocationName(_ id: String) -> String? {
        return idToLocationMap[id]
    }
    
    func getLocationID(_ name: String) -> String? {
        return locationToIDMap[name]
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                print("Device Scanner: Bluetooth is powered on")
                self.isBluetoothOn = true
                self.startScanning()
            case .poweredOff:
                print("Device Scanner: Bluetooth is powered off")
                self.isBluetoothOn = false
                self.stopScanning()
            case .unsupported:
                print("Device Scanner: Bluetooth is unsupported")
                self.isBluetoothOn = false
            case .unauthorized:
                print("Device Scanner: Bluetooth is unauthorized")
                self.isBluetoothOn = false
            case .resetting:
                print("Device Scanner: Bluetooth is resetting")
            case .unknown:
                print("Device Scanner: Bluetooth state is unknown")
            @unknown default:
                print("Device Scanner: Unknown Bluetooth state")
            }
        }
    }
    
    // MARK: - Device Scanning Methods
    
    func startScanning() {
        guard isBluetoothOn else { return }
        
        print("Device Scanner: Starting scan...")
        isScanning = true
        
        let scanOptions: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
            CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [serviceUUID]
        ]
        
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: scanOptions
        )
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                            advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if isScanning {
            var advertisedServicesArray: [CBUUID] = []
            if let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                advertisedServicesArray = advertisedServices
            }
            
            // Only process devices that advertise our service UUID
            if advertisedServicesArray.contains(serviceUUID) {
                let currentTime = Date().timeIntervalSince1970
                if currentTime - lastPrintTime >= printInterval {
                    if let fullName = peripheral.name {
                        print("\nDevice Scanner --- Advertisement Data ---")
                        print("Peripheral name: \(fullName)")
                        
                        let eid = String(fullName.prefix(23))
                        let locationID = String(fullName.dropFirst(23))
                        let locationName = self.getLocationName(locationID) ?? "Unknown Location"
                        
                        if RSSI.intValue >= -60 && locationToIDMap[currentLocationId] == locationID {
                            heardSet.updateHeardSetLog(
                                eid: eid,
                                locationId: locationName,
                                rssi: RSSI,
                                username: self.currentUsername
                            )
                            
                            print("📱 Found nearby device: \(eid)")
                            print("📍 Location Match: \(locationName)")
                            print("📶 Strong RSSI: \(RSSI)")
                        } else {
                            print("Device skipped - RSSI: \(RSSI), Device Location: \(locationID), Current Location: \(locationToIDMap[currentLocationId] ?? "unknown")")
                        }
                        
                        lastPrintTime = currentTime
                    }
                }
            }
        }
    }
    
    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }
    
    // MARK: - User management
    
    func setUsername(_ username: String) {
        self.currentUsername = username
        print("Device Scanner: Username set to \(username)")
    }
    
    // For sharing
    func getHeardLog() -> String {
        if let logContent = self.heardSet.readLogFile() {
            return logContent
        } else {
            return "No heard log available"
        }
    }
    
    deinit {
        stopScanning()
        NotificationCenter.default.removeObserver(self)
    }
} 
