import Foundation
import CoreBluetooth

class BluetoothPeripheralManager: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    @Published var isAdvertising = false
    @Published var isBluetoothOn = false
    
    private var peripheralManager: CBPeripheralManager!
    private let serviceUUID = CBUUID(string: "09bda1b5-41fa-3620-a65b-de20ab32db77") // App's service UUID
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
 // Will be set based on nearest beacon
    private var eid: String = "" //device EID
    
    private let eidGenerator = EidGenerator()
    
    private var tellSet = LogModifier()
    
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
    
    func startAdvertising(username: String, locationName: String) {
        // Only advertise if we have a valid location
        guard locationToIDMap[locationName] != nil else {
            print("Not advertising - invalid location")
            return
        }
        
        // Generate a new EID
        eid = eidGenerator.getEid()
        
        // Update tellSet with new data (use locationName instead of mappedLocationId)
        tellSet.updateLog(
            eid: eid,
            username: username,
            locationId: locationName  // Use the actual location name
        )
        
        // For advertising, use the mapped ID
        let mappedLocationId = locationToIDMap[locationName] ?? "unknown"
        
        // Setup service and start advertising
        let service = CBMutableService(type: serviceUUID, primary: true)
        peripheralManager.add(service)
        
        let tellSetData = tellSet.getLogData()
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataManufacturerDataKey: tellSetData ?? Data()
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        print("Started advertising for location: \(locationName) with EID: \(eid)")
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
        print("Stopped advertising")
    }
    
    deinit {
        stopAdvertising()
    }
} 
