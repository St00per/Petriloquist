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
let psmCharUUID = CBUUID(string: "84e3cbe2-65aa-47b1-9889-ccee3e14824a")
let packetSizeCharUUID = CBUUID(string: "ad3fde58-4a98-4ddf-b4f2-1d9423baae80")
let arrayCountCharUUID = CBUUID(string: "6016bb95-c904-4b5c-8464-3204941116ca")
let resultStringCharUUID = CBUUID(string: "1689582c-74f2-418b-8314-464d04b00c6d")

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
    var delegate: BluetoothManagerConnectDelegate?
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    var peripherals: [CBPeripheral] = []
    var petriloquistCharacteristic: CBCharacteristic!
    var transferCharacteristic: CBMutableCharacteristic?
    var channel: CBL2CAPChannel?
    var inputStream: InputStream!
    var outputStream: OutputStream!
    var isTXPortReady = true
    var packetCount = 1
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
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        self.viewController?.connectLabel.text = "DISCONNECT"
        self.peripheral.discoverServices([petriloquistCBUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print(error?.localizedDescription)
        self.viewController?.connectLabel.text = "CONNECT"
        self.viewController?.talkButtonView.alpha = 0.3
        self.viewController?.talkButtonView.isUserInteractionEnabled = false
        self.viewController?.headerView.alpha = 0.3
        self.viewController?.headerView.isUserInteractionEnabled = false
        self.viewController?.speedResultView.alpha = 0.3
        self.viewController?.speedResultsLabel.text = ""
        self.viewController?.talkButtonLabel.text = "SEND DATA"
        self.viewController?.talkButton.isUserInteractionEnabled = true
        outputStream.close()
        inputStream.close()
        channel = nil
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
            if characteristic.uuid == txCharUUID {
                print(characteristic)
                self.txCharacteristic = characteristic
            }
            if characteristic.uuid == rxCharUUID {
                self.rxCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: self.rxCharacteristic)
            }
            if characteristic.uuid == psmCharUUID {
                self.psmCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: self.psmCharacteristic)
            }
            if characteristic.uuid == packetSizeCharUUID {
                self.packetSizeCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: self.packetSizeCharacteristic)
            }
            if characteristic.uuid == arrayCountCharUUID {
                self.arrayCountCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: self.arrayCountCharacteristic)
            }
            if characteristic.uuid == resultStringCharUUID {
                self.resultStringCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: self.resultStringCharacteristic)
            }
        }
        print("Max write value with response: \(peripheral.maximumWriteValueLength(for: .withResponse))")
        print("Max write value without response: \(peripheral.maximumWriteValueLength(for: .withoutResponse))")
        self.viewController?.maxValueResponse = peripheral.maximumWriteValueLength(for: .withResponse)
        self.viewController?.maxValueNoResponse = peripheral.maximumWriteValueLength(for: .withoutResponse)
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if error != nil {
            print("Error in \(#function) :\n\(error!)")
            return
        }
        
        if characteristic.uuid == resultStringCharUUID {
            guard let resultValue = characteristic.value, let result = String(data: resultValue, encoding: .utf8) else { return }
            print(result)
            self.viewController?.speedResultsLabel.text = result
            self.viewController?.talkButtonLabel.text = "SEND DATA"
            self.viewController?.talkButton.isUserInteractionEnabled = true
            self.viewController?.speedResultView.alpha = 1
            packetCount = 0
        }
        
        if characteristic.uuid == psmCharUUID {
            if let dataValue = characteristic.value, let string = String(data: dataValue, encoding: .utf8), let psm = UInt16(string) {
                print("Opening channel \(psm)")
                self.peripheral.openL2CAPChannel(psm)
            } else {
                print("Problem decoding PSM")
            }
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
       
        self.channel = channel
        print("Opened channel \(channel)")
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
        if characteristic.uuid == packetSizeCharUUID {
           print("Packet size sent")
            self.viewController?.sendArrayCount()
        }
        if characteristic.uuid == arrayCountCharUUID {
            print("Array size sent")
            self.viewController?.sendingTimerStart()
        }
        if characteristic.uuid == txCharUUID {
            print("Packet \(packetCount) has been delivered")
            packetCount += 1
        }
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
            //UIupdate
            self.viewController?.talkButtonView.alpha = 1
            self.viewController?.talkButtonView.isUserInteractionEnabled = true
            self.viewController?.headerView.alpha = 1
            self.viewController?.headerView.isUserInteractionEnabled = true
        case Stream.Event.errorOccurred:
            print("Stream error")
        default:
            print("Unknown stream event")
        }
    }
}
