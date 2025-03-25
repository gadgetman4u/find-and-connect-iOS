import Foundation
import CoreBluetooth

class DeviceScanManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    @Published var isBluetoothOn = false
    @Published var isScanning = false
    @Published var isAdvertising = false
    
    // Current location info - will be updated from notifications
    private var currentLocationId: String = ""
    private var currentUsername: String = ""
    
    // LogModifiers for both heard and tell logs
    var heardSet: LogModifier { _heardSet }
    private var _heardSet = LogModifier(isHeardSet: true)
    
    var tellSet: LogModifier { _tellSet }
    private var _tellSet = LogModifier(isHeardSet: false)
    
    // Managers
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    
    // UUIDs
    private let serviceUUID = CBUUID(string: "09bda1b5-41fa-3620-a65b-de20ab32db77") // For finding other devices
    
    // For logging
    private var lastPrintTime: TimeInterval = 0
    private let printInterval: TimeInterval = 10.0  // 10 seconds interval
    
    // Peripheral manager properties
    private var advertisingData: [String: Any]?
    private var service: CBMutableService?
    
    // Forward mapping (name to ID)
    private let locationToIDMap: [String: String] = [
        "DPI_2038": "1",
        "DPI_2032_Conf": "2",
        "DPI_2030_Kitchen": "3",
        "DPI_2017_Conf": "4",
        "DPI_2006_Conf": "5",
        "DPI_2005_Conf": "6",
        "DPI_2054_Kitchen": "7",
        "DPI_20_2049": "8",
        "DPI_2043": "9",
        "DPI_Alvin_2042": "10",
        "DPI_2016_Hallway": "11"
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
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
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
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        DispatchQueue.main.async {
            switch peripheral.state {
            case .poweredOn:
                print("Peripheral Manager: Bluetooth powered on")
                self.isBluetoothOn = true
                // If we have advertising data ready, start advertising again
                if let data = self.advertisingData {
                    self.startAdvertisingWithData(data)
                }
            case .poweredOff:
                print("Peripheral Manager: Bluetooth powered off")
                self.isBluetoothOn = false
                self.stopAdvertising()
            case .unsupported:
                print("Peripheral Manager: Bluetooth unsupported")
            case .unauthorized:
                print("Peripheral Manager: Bluetooth unauthorized")
            case .resetting:
                print("Peripheral Manager: Bluetooth resetting")
            case .unknown:
                print("Peripheral Manager: Bluetooth unknown state")
            @unknown default:
                print("Peripheral Manager: Bluetooth unknown state")
            }
        }
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
                        
                        if RSSI.intValue >= -50 && locationToIDMap[currentLocationId] == locationID {
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
    
    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
        heardSet.clearLogFile()  // Clear heardSet when stopping
    }
    
    // MARK: - Peripheral Advertising Methods
    
    func startAdvertising(username: String, locationName: String) {
        guard let locationID = getLocationID(locationName) else {
            print("❌ Invalid location: \(locationName)")
            return
        }
        
        let eidGenerator = EidGenerator()
        let deviceEID = eidGenerator.generateEid()
        let deviceName = deviceEID + locationID
        
        // Log to the TellSet
        tellSet.updateTellSetLog(
            eid: deviceEID,
            username: username,
            locationId: locationName
        )
        
        print("Starting to advertise as \(deviceName)")
        
        let advertisingData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: deviceName
        ]
        
        self.advertisingData = advertisingData
        startAdvertisingWithData(advertisingData)
    }
    
    private func startAdvertisingWithData(_ data: [String: Any]) {
        guard peripheralManager.state == .poweredOn else {
            print("Cannot start advertising: Bluetooth not powered on")
            return
        }
        
        // Create a service and characteristics
        let service = CBMutableService(type: serviceUUID, primary: true)
        self.service = service
        
        // Add the service to the peripheral manager
        peripheralManager.add(service)
        
        // Start advertising
        peripheralManager.startAdvertising(data)
        isAdvertising = true
        print("📢 Started advertising")
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
        print("Stopped advertising")
    }
    
    // MARK: - User management
    
    func setUsername(_ username: String) {
        self.currentUsername = username
        print("Device Scanner: Username set to \(username)")
    }
    
    func getHeardLog() -> String {
        if let logContent = self.heardSet.readLogFile() {
            return logContent
        } else {
            return "No heard log available"
        }
    }
    
    func getTellLog() -> String {
        if let logContent = self.tellSet.readLogFile() {
            return logContent
        } else {
            return "No tell log available"
        }
    }
    
    deinit {
        stopScanning()
        stopAdvertising()
        NotificationCenter.default.removeObserver(self)
    }
} 