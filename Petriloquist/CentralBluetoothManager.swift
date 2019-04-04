//
//  CentralBluetoothManager.swift
//  Blueduino
//
//  Created by Kirill Shteffen on 09/01/2019.
//  Copyright © 2019 BlackBricks. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

let petriloquistCBUUID = CBUUID(string: "6C671877-0E08-4A92-921C-41F6E17A2489")
let moduleFunctionConfigurationCBUUID = CBUUID(string: "FFE1")

let txCharUUID = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
let rxCharUUID = CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616")

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
    
    var viewController: MainViewController?
    
    var centralManager: CBCentralManager!
    var petriloquistCharacteristic: CBCharacteristic!
    var transferCharacteristic: CBMutableCharacteristic?
    var channel: CBL2CAPChannel?
    var inputStream: InputStream!
    var outputStream: OutputStream!
    var peripheral: CBPeripheral!
    var isTXPortReady = true
    
    var delegate: BluetoothManagerConnectDelegate?
    
    var peripherals: [CBPeripheral] = []
    
    var txCharacteristic: CBCharacteristic!
    var rxCharacteristic: CBCharacteristic!
    var psmCharacteristic: CBCharacteristic!
    var packetSizeCharacteristic: CBCharacteristic!
    var arrayCountCharacteristic: CBCharacteristic!
    var resultStringCharacteristic: CBCharacteristic!
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
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
//            if self.peripherals.isEmpty {
//                centralManager.scanForPeripherals(withServices: [petriloquistCBUUID])
//            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print(error)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        self.viewController?.connectView.alpha = 1
        print(self.peripheral)
        central.stopScan()
        self.peripheral.delegate = self
        central.connect(self.peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        self.viewController?.connectView.backgroundColor = UIColor(hexString: "67A5A9")
        self.viewController?.connectLabel.text = "DISCONNECT"
        self.peripheral.discoverServices([petriloquistCBUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print(error?.localizedDescription)
        self.viewController?.connectView.backgroundColor = UIColor(hexString: "DE6969")
        self.viewController?.connectLabel.text = "CONNECT"
        print("Disconnected!")
    }
    
    func connect(peripheral: CBPeripheral) {
        centralManager.stopScan()
        peripheral.delegate = self
        print ("Scan stopped, try to connect...")
        centralManager.connect(peripheral, options: [:])
    }
    
    func disconnect(peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }
}

extension CentralBluetoothManager: CBPeripheralDelegate {
    
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        print("PERIPHERAL IS READY TO WRITE")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = self.peripheral.services else { return }
        for service in services {
            print(service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3") {
                print(characteristic)
                self.txCharacteristic = characteristic
//                print("Opening channel \(192)")
//                peripheral.openL2CAPChannel(CBL2CAPPSM(192))
            }
            if characteristic.uuid == CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616") {
                self.rxCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: self.rxCharacteristic)
            }
            if characteristic.uuid == CBUUID(string: "84e3cbe2-65aa-47b1-9889-ccee3e14824a") {
                self.psmCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: self.psmCharacteristic)
            }
            if characteristic.uuid == CBUUID(string: "ad3fde58-4a98-4ddf-b4f2-1d9423baae80") {
                self.packetSizeCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: self.packetSizeCharacteristic)
            }
            if characteristic.uuid == CBUUID(string: "6016bb95-c904-4b5c-8464-3204941116ca") {
                self.arrayCountCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: self.arrayCountCharacteristic)
            }
            if characteristic.uuid == CBUUID(string: "1689582c-74f2-418b-8314-464d04b00c6d") {
                self.resultStringCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: self.resultStringCharacteristic)
            }
            
        }
        print("Max write value with response: \(peripheral.maximumWriteValueLength(for: .withResponse))")
        print("Max write value without response: \(peripheral.maximumWriteValueLength(for: .withoutResponse))")
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        print(#function)
        print("characteristic : \(characteristic) \n\(characteristic.uuid)")
        if error != nil {
            print("Error in \(#function) :\n\(error!)")
            return
        }
        
        print("Read characteristic \(characteristic)")
        
        if let dataValue = characteristic.value, let string = String(data: dataValue, encoding: .utf8), let psm = UInt16(string) {
            print("Opening channel \(psm)")
            self.peripheral.openL2CAPChannel(psm)
            
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
        //self.channel = channel
     
        if let currentChannel = self.channel {
            if currentChannel != channel
            {print("cbL2CAPChan will change")}
            if outputStream != channel.outputStream
            {print("outPutStream will change")}
            if inputStream != channel.inputStream
            {print("inPutStream will change")}
            outputStream.close()
            inputStream.close()
        }
        
        self.channel = channel
        outputStream = channel.outputStream
        outputStream.delegate = self
        outputStream.schedule(in: .current, forMode: .default)
        outputStream.open()
        
        
        
        inputStream = channel.inputStream
        inputStream.delegate = self
        inputStream.schedule(in: .current, forMode: .default)
        inputStream.open()
 
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
