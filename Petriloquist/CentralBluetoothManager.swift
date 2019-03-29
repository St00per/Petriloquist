//
//  CentralBluetoothManager.swift
//  Blueduino
//
//  Created by Kirill Shteffen on 09/01/2019.
//  Copyright © 2019 BlackBricks. All rights reserved.
//

import Foundation
import CoreBluetooth

let petriloquistCBUUID = CBUUID(string: "0xFFE0")
let moduleFunctionConfigurationCBUUID = CBUUID(string: "FFE1")

public protocol BluetoothManagerConnectDelegate {
    func connectingStateSet()
}

enum DeviceConnectionState {
    case disconnected
    case connecting
    case connected
}

class CentralBluetoothManager: NSObject {
    
    public static let `default` = CentralBluetoothManager()
    
    var centralManager: CBCentralManager!
    var foundDevices: [CBPeripheral] = []
    var petriloquistCharacteristic: CBCharacteristic!
    var transferCharacteristic: CBMutableCharacteristic?
    var channel: CBL2CAPChannel?
    
    var isFirstDidLoad = true
    var delegate: BluetoothManagerConnectDelegate?
    
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
}

extension CentralBluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
            if isFirstDidLoad {
                centralManager.scanForPeripherals(withServices: [petriloquistCBUUID])
                
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print(error)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        connect(peripheral: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        peripheral.discoverServices(nil)
        //peripheral.openL2CAPChannel(<#T##PSM: CBL2CAPPSM##CBL2CAPPSM#>)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected!")
    }
    
    func connect(peripheral: CBPeripheral) {
        centralManager.stopScan()
        print ("Scan stopped, try to connect...")
        peripheral.delegate = self
        centralManager.connect(peripheral)
    }
    
    func disconnect(peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }
}

extension CentralBluetoothManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            print(service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print(characteristic)
            print(characteristic.properties)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Characteristic update error - \(error)")
            return
        }
        
        print("Read characteristic \(characteristic)")
        
        if let dataValue = characteristic.value, let string = String(data: dataValue, encoding: .utf8), let psm = UInt16(string) {
            print("Opening channel \(psm)")
            peripheral.openL2CAPChannel(psm)
        } else {
            print("Problem decoding PSM")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        if let error = error {
            print("Error opening l2cap channel - \(error.localizedDescription)")
            return
        }
        guard let channel = channel else {
            return
        }
        print("Opened channel \(channel)")
        self.channel = channel
        channel.inputStream.delegate = self
        channel.outputStream.delegate = self
        print("Opened channel \(channel)")
        channel.inputStream.schedule(in: RunLoop.current, forMode: .default)
        channel.outputStream.schedule(in: RunLoop.current, forMode: .default)
        channel.inputStream.open()
        channel.outputStream.open()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Message sent")
    }
}

extension CentralBluetoothManager: StreamDelegate {
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.openCompleted:
            print("Stream is open")
        case Stream.Event.endEncountered:
            print("End Encountered")
        case Stream.Event.hasBytesAvailable:
            print("Bytes are available")
        case Stream.Event.hasSpaceAvailable:
            print("Space is available")
        case Stream.Event.errorOccurred:
            print("Stream error")
        default:
            print("Unknown stream event")
        }
    }
}
