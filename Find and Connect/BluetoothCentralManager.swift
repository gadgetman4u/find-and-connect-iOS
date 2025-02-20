import Foundation
import CoreBluetooth

class BluetoothCentralManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var isBluetoothOn = false
    @Published var lastRSSI: NSNumber?
    @Published var nearestBeaconId: String?
    @Published var discoveredBeacons: [String] = []
    @Published var isScanning = false
    @Published var currentLocationId: String = ""
    
    // Forward mapping (name to ID)
    private let locationToIDMap: [String: String] = [
        "DPI_2038": "1",
        "DPI_2032_Conf": "2",
        "DPI_2030_Kitchen": "3",
        "DPI_2017_Conf": "4",
        "DPI_2006_Conf": "5",
        "DPI_2005_Conf_1": "6",
        "DPI_2005_Conf_2": "6",
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
    
    // Helper functions
    func getLocationID(_ name: String) -> String? {
        return locationToIDMap[name]
    }
    
    func getLocationName(_ id: String) -> String? {
        return idToLocationMap[id]
    }
    
    private var centralManager: CBCentralManager!
    private let beaconUUID = CBUUID(string: "00002080-0000-1000-8000-00805f9b34fb") // For finding beacons
    private let serviceUUID = CBUUID(string: "09bda1b5-41fa-3620-a65b-de20ab32db77") // For finding other devices
    private var beaconRSSIMap: [String: NSNumber] = [:]
    var heardSet: LogModifier { _heardSet }
    private var _heardSet = LogModifier(isHeardSet: true)
    
    private var scanTimer: Timer?
    @Published var isRoomScanActive = true // Track which scan mode is active
    
    private var lastPrintTime: TimeInterval = 0  // Add this property
    private let printInterval: TimeInterval = 5.0  // 5 seconds interval
    
    // Add property for username
    private var currentUsername: String = ""
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                print("Bluetooth is powered on")
                self.isBluetoothOn = true
                self.startScanningBeacon()
            case .poweredOff:
                print("Bluetooth is powered off")
                self.isBluetoothOn = false
                self.beaconRSSIMap.removeAll()
            case .unsupported:
                print("Bluetooth is unsupported") //bluetooth unsupported on their device
            case .unauthorized:
                print("Bluetooth is unauthorized") //ask for permission
            case .resetting:
                print("Bluetooth is resetting") //wait for next state update
            case .unknown:
                print("Bluetooth state is unknown") //wait for next state update
            @unknown default:
                print("Unknown Bluetooth state")
            }
            
            self.isBluetoothOn = central.state == .poweredOn
        }
    }
    
    func startScanningBeacon() {
        print("Starting scan cycle...")
        isScanning = true
        
        // Start with room scanning
        scanForRooms()
        
        scanTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            print("Timer fired, isRoomScanActive: \(self.isRoomScanActive)")
            print("Discovered beacons count: \(self.discoveredBeacons.count)")
            
            if self.isRoomScanActive {
                if !self.discoveredBeacons.isEmpty {
                    print("Switching to device scanning")
                    self.scanForDevices()
                } else {
                    print("No beacons discovered yet, staying in room scan mode")
                }
            } else {
                print("Switching back to room scanning")
                self.scanForRooms()
            }
            
            self.isRoomScanActive.toggle()
        }
    }
    
    private func scanForRooms() {
        print("Scanning for rooms...")
        centralManager.stopScan()
        centralManager.scanForPeripherals(
            withServices: [beaconUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }
    
    private func scanForDevices() {
        print("Starting device scan cycle...")
        centralManager.stopScan()
        
        let scanOptions: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
            CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [serviceUUID]
        ]
        
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: scanOptions
        )
        print("Now scanning for devices with UUID: \(serviceUUID.uuidString)")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if isScanning {
            var advertisedServicesArray: [CBUUID] = []
            if let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                advertisedServicesArray = advertisedServices
            }
            
            if self.isRoomScanActive {
                // If the advertisement data doesn't include the service list,
                // or if it does and it contains the beaconUUID, process it as a room beacon.
                if advertisedServicesArray.isEmpty || advertisedServicesArray.contains(beaconUUID) {
                    // Handle room discovery
                    let locationId = peripheral.name ?? peripheral.identifier.uuidString
                    beaconRSSIMap[locationId] = RSSI
                    
                    print("Room Scan - Found beacon: \(locationId), RSSI: \(RSSI)")
                    print("Current discovered beacons: \(discoveredBeacons)")
                    
                    if let strongestBeacon = beaconRSSIMap.max(by: { $0.value.intValue < $1.value.intValue }) {
                        DispatchQueue.main.async {
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
                            
                            if !self.discoveredBeacons.contains(locationId) {
                                self.discoveredBeacons.append(locationId)
                            }
                        }
                    }
                } else {
                    print("Skipped non-beacon with advertised services: \(advertisedServicesArray)")
                }
            } else {
                // Device scanning branch
                if advertisedServicesArray.contains(serviceUUID) {
                    // Debug prints moved outside time check
                    let currentTime = Date().timeIntervalSince1970
                    if currentTime - lastPrintTime >= printInterval {
                        for(key, value) in advertisementData {
                            print("Key: \(key), Value: \(value)")
                        }
                        if let fullName = peripheral.name {
                            print("\n--- Advertisement Data ---")
                            print("Peripheral name: \(fullName)")
                            let eid = String(fullName.prefix(23))
                            let locationID = String(fullName.dropFirst(23))
                            let locationName = self.getLocationName(locationID) ?? "Unknown Location"
                            
                            if RSSI.intValue >= -70 && locationToIDMap[currentLocationId] == locationID {
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
                        } else {
                            print("Name is nil")
                        }
                    }
                } else {
                    print("Skipped non-device service: \(advertisedServicesArray)")
                }
            }
        }
    }
    
    func stopScanning() {
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
        centralManager.stopScan()
        beaconRSSIMap.removeAll()
        discoveredBeacons.removeAll()
        nearestBeaconId = nil
        currentLocationId = ""
        NotificationCenter.default.post(
            name: Notification.Name("OutOfRange"),
            object: nil
        )
        heardSet.clearLogFile()  // Clear heardSet when stopping
    }
    
    deinit {
        stopScanning()
    }
    
    // Add method to set username
    func setUsername(_ username: String) {
        self.currentUsername = username
    }
} 
