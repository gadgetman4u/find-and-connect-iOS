import Foundation
import CoreBluetooth

struct HeardSetEntry {
    let timestamp: TimeInterval
    let deviceUUID: String
    let locationId: String
    let rssi: NSNumber
}

class BluetoothCentralManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var isBluetoothOn = false
    @Published var lastRSSI: NSNumber?
    @Published var nearestBeaconId: String?
    @Published var discoveredBeacons: [String] = []
    @Published var isScanning = false
    @Published var currentLocationId: String = ""
    
    private var centralManager: CBCentralManager!
    private let beaconUUID = CBUUID(string: "00002080-0000-1000-8000-00805f9b34fb") // For finding beacons
    private let serviceUUID = CBUUID(string: "09bda1b5-41fa-3620-a65b-de20ab32db77") // For finding other devices
    private var beaconRSSIMap: [String: NSNumber] = [:]
    private var heardSet: [HeardSetEntry] = []
    
    private var scanTimer: Timer?
    private var isRoomScanActive = true // Track which scan mode is active
    
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
        
        // Setup timer to alternate between room and device scanning
        scanTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.isRoomScanActive {
                // Switch to device scanning if we have a current location
                if !self.discoveredBeacons.isEmpty {
                    self.scanForDevices()
                }
            } else {
                // Switch back to room scanning
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
        print("Scanning for devices...")
        centralManager.stopScan()
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if isScanning {
            if isRoomScanActive {
                // Handle room discovery
                let locationId = peripheral.name ?? peripheral.identifier.uuidString
                beaconRSSIMap[locationId] = RSSI
                
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
                // Handle device discovery
                if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
                   let tellSetData = try? JSONSerialization.jsonObject(with: manufacturerData) as? [String: Any],
                   let timestamp = tellSetData["timestamp"] as? TimeInterval,
                   let deviceUUID = tellSetData["deviceUUID"] as? String,
                   let locationId = tellSetData["locationId"] as? String {
                    
                    let entry = HeardSetEntry(
                        timestamp: timestamp,
                        deviceUUID: deviceUUID,
                        locationId: locationId,
                        rssi: RSSI
                    )
                    
                    heardSet.append(entry)
                    print("Added to heardSet: \(entry)")
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
    }
    
    // Add method to access heardSet data
    func getHeardSetEntries() -> [HeardSetEntry] {
        return heardSet
    }
    
    deinit {
        stopScanning()
    }
} 
