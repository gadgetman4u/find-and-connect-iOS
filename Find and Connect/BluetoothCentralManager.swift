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
    @Published var isLocked = false
    @Published var currentLocationId: String = ""
    
    private var centralManager: CBCentralManager!
    private let beaconUUID = CBUUID(string: "00002080-0000-1000-8000-00805f9b34fb") // For finding beacons
    private let serviceUUID = CBUUID(string: "09bda1b5-41fa-3620-a65b-de20ab32db77") // For finding other devices
    private var beaconRSSIMap: [String: NSNumber] = [:]
    private var heardSet: [HeardSetEntry] = []
    
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
                self.startScanning()
            case .poweredOff:
                print("Bluetooth is powered off")
                self.isBluetoothOn = false
                self.beaconRSSIMap.removeAll()
            case .unsupported:
                print("Bluetooth is unsupported")
            case .unauthorized:
                print("Bluetooth is unauthorized")
            case .resetting:
                print("Bluetooth is resetting")
            case .unknown:
                print("Bluetooth state is unknown")
            @unknown default:
                print("Unknown Bluetooth state")
            }
            
            self.isBluetoothOn = central.state == .poweredOn
        }
    }
    
    func startScanning() {
        print("Starting beacon scan...")
        centralManager.scanForPeripherals(
            withServices: [beaconUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if isLocked {
            // Handle device discovery
            if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
               let tellSetData = try? JSONSerialization.jsonObject(with: manufacturerData) as? [String: Any],
               let timestamp = tellSetData["timestamp"] as? TimeInterval,
               let deviceUUID = tellSetData["deviceUUID"] as? String,
               let locationId = tellSetData["locationId"] as? String {
                
                // Create heardSet entry
                let entry = HeardSetEntry(
                    timestamp: timestamp,
                    deviceUUID: deviceUUID,
                    locationId: locationId,
                    rssi: RSSI
                )
                
                heardSet.append(entry)
                print("Added to heardSet: \(entry)")
            }
        } else {
            // Handle beacon discovery (existing code)
            let locationId = peripheral.name ?? peripheral.identifier.uuidString
            beaconRSSIMap[locationId] = RSSI
            
            if let strongestBeacon = beaconRSSIMap.max(by: { $0.value.intValue < $1.value.intValue }) {
                DispatchQueue.main.async {
                    self.lastRSSI = strongestBeacon.value
                    self.nearestBeaconId = strongestBeacon.key
                    self.currentLocationId = strongestBeacon.key // Store location ID
                    
                    if !self.discoveredBeacons.contains(locationId) {
                        self.discoveredBeacons.append(locationId)
                    }
                }
            }
        }
    }
    
    func lockOnBeacon() {
        isLocked = true
        centralManager.stopScan()
        
        // Start scanning for other devices using app's service UUID
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        print("Locked on beacon and scanning for other devices")
    }
    
    func unlockBeacon() {
        isLocked = false
        centralManager.stopScan()
        startScanning()
    }
    
    func stopScanning() {
        centralManager.stopScan()
        beaconRSSIMap.removeAll()
    }
    
    // Add method to access heardSet data
    func getHeardSetEntries() -> [HeardSetEntry] {
        return heardSet
    }
    
    deinit {
        stopScanning()
    }
} 
