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

// service and characteristics IDs
let petriloquistCBUUID = CBUUID(string: "6C671877-0E08-4A92-921C-41F6E17A2489")
let txCharUUID = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
let rxCharUUID = CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616")
let psmCharUUID = CBUUID(string: "84e3cbe2-65aa-47b1-9889-ccee3e14824a")
//speed test characteristics
let packetSizeCharUUID = CBUUID(string: "ad3fde58-4a98-4ddf-b4f2-1d9423baae80")
let arrayCountCharUUID = CBUUID(string: "6016bb95-c904-4b5c-8464-3204941116ca")
let resultStringCharUUID = CBUUID(string: "1689582c-74f2-418b-8314-464d04b00c6d")
//Cypress char
let cypressCharUUID = CBUUID(string: "F81E56D4-54D5-4DD4-BE72-8291A336F21E")

public protocol BluetoothManagerConnectDelegate {
    func connectingStateSet()
}

protocol BluetoothManagerUIDelegate {
    var maxValueResponse: Int { get set }
    var maxValueNoResponse: Int { get set }
    var startingPoint: Int { get set }
    var speedResult: String { get set }
    var recSamples: [Float] { get set }
    var sendingIsComplete: Bool { get set }
    func uiUpdate(uiState: uiState)
    func sendPacketSize()
    func sendArrayCount()
    func sendingTimerStart()
}

enum sendingMode {
    case speedTest
    case voice
}

class CentralBluetoothManager: NSObject {
    
    public static let `default` = CentralBluetoothManager()
    
    //var viewController: MainViewController?
    var uiDelegate: BluetoothManagerUIDelegate?
    var talkModeViewController: TalkModeViewController?
    var connectDelegate: BluetoothManagerConnectDelegate?
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    var peripherals: [CBPeripheral] = []
    var petriloquistCharacteristic: CBCharacteristic!
    var transferCharacteristic: CBMutableCharacteristic?
    var channel: CBL2CAPChannel?
    var inputStream: InputStream!
    var outputStream: OutputStream!
    var isTXPortReady = true
    var speedTestStarted = true
    var sendingMode: sendingMode = .speedTest
    var packetCount = 1
    var txCharacteristic: CBCharacteristic!
    var rxCharacteristic: CBCharacteristic!
    var cypressCharacteristic: CBCharacteristic!
    var psmCharacteristic: CBCharacteristic!
    var packetSizeCharacteristic: CBCharacteristic!
    var arrayCountCharacteristic: CBCharacteristic!
    var resultStringCharacteristic: CBCharacteristic!
    var cypressUpdateCount = 0
    var startingTime: NSDate!
    
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
        self.uiDelegate?.uiUpdate(uiState: .afterSearch)
        print(self.peripheral)
        central.stopScan()
        self.peripheral.delegate = self
        
        if peripheral.name == "GATT_Out" {
            self.peripheral = peripheral
            print(self.peripheral)
            central.stopScan()
            self.peripheral.delegate = self
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        self.uiDelegate?.uiUpdate(uiState: .afterConnect)
        self.peripheral.discoverServices([petriloquistCBUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print(error?.localizedDescription)
        self.uiDelegate?.uiUpdate(uiState: .afterDisconnect)
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
            if characteristic.uuid == cypressCharUUID {
                self.cypressCharacteristic = characteristic
                
            }
        }
        print("Max write value with response: \(peripheral.maximumWriteValueLength(for: .withResponse))")
        print("Max write value without response: \(peripheral.maximumWriteValueLength(for: .withoutResponse))")
        self.uiDelegate?.maxValueResponse = peripheral.maximumWriteValueLength(for: .withResponse)
        self.uiDelegate?.maxValueNoResponse = peripheral.maximumWriteValueLength(for: .withoutResponse)
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
            if result == "SpeedTest" {
                sendingMode = .speedTest
                self.uiDelegate?.sendPacketSize()
                speedTestStarted = true
            }
            if result == "Voice" {
                sendingMode = .voice
                self.uiDelegate?.startingPoint = 0// - ?
                self.uiDelegate?.recSamples = []
                self.uiDelegate?.sendingTimerStart()
            }
            if ((uiDelegate as? MainViewController) != nil), sendingMode == .speedTest, result != "SpeedTest", result != "Voice" {
                self.uiDelegate?.speedResult = result
                self.uiDelegate?.uiUpdate(uiState: .dataHasSent)
            }
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
        
        if characteristic.uuid == cypressCharUUID {
            if let value = characteristic.value {
                //print(Array(value))
                cypressUpdateCount += 1
                
                //MARK: Cypress Receiving Speed Calculation
                if Date().timeIntervalSince(startingTime as Date) > 1 {
                    startingTime = NSDate()
                    let currentTransferSpeed = (Int(495 * cypressUpdateCount) * 8)/1000
                    //print (currentTransferSpeed)
                    cypressUpdateCount = 0
                    self.uiDelegate?.speedResult = "\(currentTransferSpeed) Kb/s"
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Write error")
            return
        }
        if characteristic.uuid == packetSizeCharUUID {
            print("Packet size sent")
            if ((uiDelegate as? MainViewController) != nil) {
                if speedTestStarted {
                    self.uiDelegate?.sendArrayCount()
                    speedTestStarted = false
                }
            }
            if ((uiDelegate as? TalkModeViewController) != nil) {
                self.uiDelegate?.sendPacketSize()
            }
        }
        if characteristic.uuid == arrayCountCharUUID {
            //print("Total data count has sent \(String(describing: self.viewController?.recSamples.count))")
            if ((uiDelegate as? MainViewController) != nil) {
                self.uiDelegate?.startingPoint = 0
                self.uiDelegate?.sendingTimerStart()
            }
        }
        if characteristic.uuid == txCharUUID {
            print("Packet \(packetCount) has been delivered")
            packetCount += 1
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
            self.uiDelegate?.uiUpdate(uiState: .afterChannelOpening)
        case Stream.Event.errorOccurred:
            print("Stream error")
        default:
            print("Unknown stream event")
        }
    }
}
