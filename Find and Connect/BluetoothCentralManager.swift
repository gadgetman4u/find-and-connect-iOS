import Foundation
import CoreBluetooth

struct HeardSetEntry: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    let rssi: NSNumber
    let timestamp: TimeInterval
    
    // Add computed property for display
    var displayName: String {
        return name
    }
}

class BluetoothCentralManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var isBluetoothOn = false
    @Published var lastRSSI: NSNumber?
    @Published var nearestBeaconId: String?
    @Published var discoveredBeacons: [String] = []
    @Published var isScanning = false
    @Published var currentLocationId: String = ""
    @Published var discoveredDevices: [HeardSetEntry] = []
    
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
        print("Scanning for devices with service UUID: \(serviceUUID.uuidString)")
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
                let currentTime = Date().timeIntervalSince1970
                // Only print if 5 seconds have passed since last print
                if currentTime - lastPrintTime >= printInterval {
                    print("📱 Found peripheral: \(peripheral.name ?? "Unknown")")
                    
                    if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                        print("🛠 Advertised Service UUIDs: \(serviceUUIDs)")
                        
                        if let eidUUID = serviceUUIDs.first(where: { $0 != CBUUID(string: "09bda1b5-41fa-3620-a65b-de20ab32db77") }) {
                            print("🔑 Extracted EID: \(eidUUID.uuidString)")
                        }
                    }
                    
                    
                    
                    if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
                        print("📝 Raw Manufacturer data: \(manufacturerData as NSData)")
                        if let dataString = String(data: manufacturerData, encoding: .utf8) {
                            print("📝 Manufacturer data as string: \(dataString)")
                        }
                    }
                    
                    if let combinedString = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
                       let dataString = String(data: combinedString, encoding: .utf8) {
                        let components = dataString.split(separator: "|")
                        if components.count == 2 {
                            let eid = String(components[0])
                            let location = String(components[1])
                            print("🔑 Parsed EID: \(eid)")
                            print("📍 Parsed Location: \(location)")
                        } else {
                            print("❌ Could not parse manufacturer data: \(dataString)")
                        }
                    }
                    
                    print("📶 RSSI: \(RSSI)")
                    lastPrintTime = currentTime
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
} 
