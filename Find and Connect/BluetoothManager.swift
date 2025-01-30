import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var discoveredDevices: [(name: String, peripheral: CBPeripheral)] = []
    @Published var isPaired = false
    @Published var currentDeviceName: String?
    @Published var pairingProgress: Double = 0
    @Published var isPairing = false
    @Published var receivedData: [String: Any] = [:]
    @Published var pairingText = "Pairing."
    @Published var isBluetoothOn = false
    
    private var centralManager: CBCentralManager!
    private let targetUUID = CBUUID(string: "00002080-0000-1000-8000-00805f9b34fb")
    private var pairingTimer: Timer?
    private var connectedPeripheral: CBPeripheral?
    private var progressTimer: Timer?
    private var textAnimationTimer: Timer?
    
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
                self.isPairing = false
                self.isPaired = false
                self.discoveredDevices.removeAll()
            default:
                print("Bluetooth state: \(central.state)")
                self.isBluetoothOn = false
            }
        }
    }
    
    func startScanning() {
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: [targetUUID], options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let deviceName = peripheral.name {
            if !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
                discoveredDevices.append((name: deviceName, peripheral: peripheral))
            }
        }
    }
    
    func pair(with device: (name: String, peripheral: CBPeripheral)) {
        isPairing = true
        pairingProgress = 0
        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self
        
        // Start pairing animation
        var dotCount = 1
        textAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.pairingText = "Pairing" + String(repeating: ".", count: dotCount)
                dotCount = (dotCount % 3) + 1
            }
        }
        
        // Attempt to connect
        centralManager.connect(device.peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
    }
    
    // Called when device is connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "")")
        
        // Start filling progress bar after connection
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            DispatchQueue.main.async {
                if self.pairingProgress < 1.0 {
                    self.pairingProgress += 0.02
                } else {
                    timer.invalidate()
                    self.progressTimer = nil
                    self.completePairing(peripheral: peripheral)
                }
            }
        }
        
        // Discover services after connection
        peripheral.discoverServices(nil)
    }
    
    private func completePairing(peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.isPairing = false
            self.isPaired = true
            self.currentDeviceName = peripheral.name
            self.pairingProgress = 1.0
            self.textAnimationTimer?.invalidate()
            self.textAnimationTimer = nil
            
            // Stop scanning once successfully connected
            self.centralManager.stopScan()
        }
    }
    
    // Called when services are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("Discovered service: \(service)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // Called when characteristics are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print("Discovered characteristic: \(characteristic)")
            
            // Enable notification if the characteristic supports it
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            // Read value if the characteristic supports it
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    // Called when characteristic value is updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        // Handle the received data based on characteristic UUID
        print("Received data for characteristic \(characteristic.uuid): \(data)")
        
        // Example of parsing data - modify based on your beacon's data format
        if let stringValue = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.receivedData[characteristic.uuid.uuidString] = stringValue
            }
        }
    }
    
    func disconnect() {
        progressTimer?.invalidate()
        progressTimer = nil
        textAnimationTimer?.invalidate()
        textAnimationTimer = nil
        
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        DispatchQueue.main.async {
            self.isPaired = false
            self.currentDeviceName = nil
            self.pairingProgress = 0
            self.receivedData.removeAll()
        }
        startScanning()
    }
    
    // Called when device is disconnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral: \(peripheral.name ?? "")")
        if let error = error {
            print("Disconnection error: \(error.localizedDescription)")
        }
        
        // Only reset state if this is the currently connected peripheral
        if peripheral.identifier == connectedPeripheral?.identifier {
            DispatchQueue.main.async {
                self.connectedPeripheral = nil
                self.isPaired = false
                self.currentDeviceName = nil
                self.pairingProgress = 0
                self.receivedData.removeAll()
                self.progressTimer?.invalidate()
                self.progressTimer = nil
            }
            startScanning()
        }
    }
    
    func cancelPairing() {
        // Invalidate timers
        progressTimer?.invalidate()
        progressTimer = nil
        textAnimationTimer?.invalidate()
        textAnimationTimer = nil
        
        // If connected, disconnect from the peripheral
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        // Reset pairing state
        DispatchQueue.main.async {
            self.isPairing = false
            self.pairingProgress = 0
            self.pairingText = "Pairing."
            self.connectedPeripheral = nil
        }
        
        // Restart scanning
        startScanning()
    }
    
    deinit {
        progressTimer?.invalidate()
        textAnimationTimer?.invalidate()
    }
} 
