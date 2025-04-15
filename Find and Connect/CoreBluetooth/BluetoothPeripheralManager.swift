import Foundation
import CoreBluetooth

class BluetoothPeripheralManager: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    @Published var isAdvertising = false
    @Published var isBluetoothOn = false
    
    private var peripheralManager: CBPeripheralManager!
    private let serviceUUID = CBUUID(string: "09bda1b5-41fa-3620-a65b-de20ab32db77") // App's service UUID
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
    
    
    func getLocationName(_ id: String) -> String? {
        return idToLocationMap[id]
    }
    
    // Will be set based on nearest beacon
    private var eid: String = "" //device EID
    
    private let eidGenerator = EidGenerator()
    
    // Make tellSet accessible for testing
    var tellSet: LogModifier { _tellSet }
    private var _tellSet = LogModifier()
    
    private var logTimer: Timer?
    private var currentUsername: String = ""
    private var currentLocation: String = ""
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        DispatchQueue.main.async {
            switch peripheral.state {
            case .poweredOn:
                print("Bluetooth is powered on")
                self.isBluetoothOn = true
            case .poweredOff:
                print("Bluetooth is powered off")
                self.isBluetoothOn = false
                self.stopAdvertising()
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
        }
    }
    
    private func updateAdvertisement(withEid eid: String) {
        // Get location ID using helper function
        let locationID = locationToIDMap[currentLocation] ?? "0"
        let localName = eid + locationID
        print("This is the advertising fullName: \(localName)")
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: localName
        ]
        
        for(key, value) in advertisementData {
            print("Key: \(key), Value: \(value)")
        }
        
        peripheralManager.stopAdvertising()
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        print("Advertising with EID: \(eid), LocationID: \(locationID), Location: \(currentLocation)")
    }
    
    func startAdvertising(username: String, locationName: String) {
        // Only advertise if we have a valid location
//        guard let locationID = getLocationID(locationName) else {
//            print("Not advertising - invalid location: \(locationName)")
//            return
//        }
        
        // Generate a new EID
        eid = eidGenerator.generateEid()
        print("Generated EID: \(eid)")
        
        self.currentUsername = username
        self.currentLocation = locationName
        
        // Update tellSet log
        tellSet.updateTellSetLog(
            eid: eid,
            username: username,
            locationId: locationName
        )
        
        // Start periodic logging
        startPeriodicLogging()
        
        // Update advertisement with initial EID and location
        updateAdvertisement(withEid: eid)
    }
    
    private func startPeriodicLogging() {
        logTimer?.invalidate()
        
        logTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.eid = self.eidGenerator.generateEid()
            print("Generated new EID: \(self.eid)")
            
            self.tellSet.updateTellSetLog(
                eid: self.eid,
                username: self.currentUsername,
                locationId: self.currentLocation
            )
            
            self.updateAdvertisement(withEid: self.eid)
        }
    }
    
    func stopAdvertising() {
        logTimer?.invalidate()
        logTimer = nil
        peripheralManager.stopAdvertising()
        isAdvertising = false
        print("Stopped advertising")
    }
    
    deinit {
        logTimer?.invalidate()
        stopAdvertising()
    }

    // For sharing
    func getTellLog() -> String {
        // Return the tell log content
        // Replace this with your actual implementation to access the log
        if let logContent = self.tellSet.readLogFile() {
            return logContent
        } else {
            return "No tell log available"
        }
    }
} 
