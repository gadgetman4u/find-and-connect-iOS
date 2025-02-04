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
    private let deviceUUID = UUID() // Unique identifier for this device
    
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
        // Convert location name to ID using the map
        let mappedLocationId = locationToIDMap[locationName] ?? "unknown"
        
        // Create tellSet data
        let tellSetData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "deviceUUID": deviceUUID.uuidString,
            "username": username,
            "locationId": mappedLocationId  // use the mapped ID
        ]
        
        // Convert tellSet to Data
        let jsonData = try? JSONSerialization.data(withJSONObject: tellSetData)
        
        // Setup service
        let service = CBMutableService(type: serviceUUID, primary: true)
        peripheralManager.add(service)
        
        // Setup advertisement data
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataManufacturerDataKey: jsonData ?? Data()
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        print("Started advertising with tellSet: \(tellSetData)")
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
