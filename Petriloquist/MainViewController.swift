//
//  MainViewController.swift
//  Petriloquist
//
//  Created by Kirill Shteffen on 29/03/2019.
//  Copyright © 2019 BlackBricks. All rights reserved.
//

import UIKit
import AVFoundation
import AudioToolbox
import CoreBluetooth

public enum uiState {
    case firstLoad
    case afterSearch
    case afterConnect
    case afterChannelOpening
    case afterDisconnect
    case dataAreSending
    case dataHasSent
}

class MainViewController: UIViewController, AVAudioRecorderDelegate, BluetoothManagerUIDelegate {
  
    @IBOutlet weak var l2CapButtonView: UIView!
    @IBOutlet weak var responseButtonView: UIView!
    @IBOutlet weak var noResponseButtonView: UIView!
    @IBOutlet weak var scanView: UIView!
    @IBOutlet weak var connectView: UIView!
    @IBOutlet weak var connectLabel: UILabel!
    @IBOutlet weak var downloadView: UIView!
    @IBOutlet weak var listenButton: UIButton!
    @IBOutlet weak var talkButton: UIButton!
    @IBOutlet weak var talkButtonLabel: UILabel!
    @IBOutlet weak var talkButtonView: UIView!
    @IBOutlet weak var sendingTypeLabel: UILabel!
    @IBOutlet weak var totalDataLabel: UILabel!
    @IBOutlet weak var listenView: UIView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var speedResultView: UIView!
    @IBOutlet weak var speedResultsLabel: UILabel!
    @IBOutlet weak var packetSizeSlider: UISlider!
    @IBOutlet weak var packetSizeLabel: UILabel!
    
    enum sendingType {
        case l2Cap
        case withResponse
        case withoutResponse
    }
 
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    //var audioCodec: AudioCodec!
    var audioInput: TempiAudioInput!
    var testArray: [Float32] = []
    var recSamples: [Float] = [] {
        didSet {
            //ToneGenerator.pcmArray = recSamples
        }
    }
    var speedResult: String = "" {
        didSet {
            speedResultsLabel.text = speedResult
        }
    }
    var wholeTestData = Data()
    var startingPoint = 0
    var dataPacketSize = 176
    var maxValueResponse = 0
    var maxValueNoResponse = 0
    var testDataTimer: Timer!
    var sendingIsComplete: Bool = false
    var selectedSendingType: sendingType = .l2Cap
    var managerBluetooth = CentralBluetoothManager()
    
    //Cypess testing variables
    var transferStartTime: NSDate!
    var lastConnectionInterval: TimeInterval! = 0
    var connectionIntervals: [TimeInterval] = []
    var averageConnectionInterval: TimeInterval {
        get {
            if connectionIntervals.count > UInt8.max {
                connectionIntervals = [connectionIntervals.last!]
                return connectionIntervals.last!
            }
            var sum: TimeInterval = 0
            for interval in connectionIntervals {
                sum += interval
            }
            return sum / Double(connectionIntervals.count)
        }
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        //UIpreparation
        uiUpdate(uiState: .firstLoad)

        //Bluetooth manager init
        managerBluetooth = CentralBluetoothManager.default
    }
    
    override func viewWillAppear(_ animated: Bool) {
        managerBluetooth.uiDelegate = self
        managerBluetooth.sendingMode = .speedTest
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        guard managerBluetooth.peripheral != nil, managerBluetooth.peripheral.state == .connected else { return }
        managerBluetooth.disconnect(peripheral: managerBluetooth.peripheral)
    }
    
    //Array size calculation for selected packet size
    func calculatedArraySize(packetSize: Int) -> Int {
        self.dataPacketSize = packetSize
        var calculatedArraySize = 0
        let sizesRatio = 20000/packetSize
        calculatedArraySize = sizesRatio * packetSize
        if calculatedArraySize < 20000 {
            calculatedArraySize = (sizesRatio * packetSize) + packetSize
        }
        return calculatedArraySize
    }
    
    //Data array init
    func fillTestFloatArray(totalSize: Int) {
        for _ in 1...totalSize {
            testArray.append(Float32(1))
        }
    }
 
    func l2CapDataSend() {
        print("TRY TO SEND")
        guard let ostream = managerBluetooth.channel?.outputStream else {
            return
        }
        if ostream.hasSpaceAvailable {
            
            let testData = wholeTestData.subdata(in: startingPoint..<startingPoint + dataPacketSize)
                _ = testData.withUnsafeBytes { ostream.write($0, maxLength: testData.count)}
                self.startingPoint = startingPoint + dataPacketSize
        }
    }
    
    func charDataSend(withResponse: Bool) {
        print("TRY TO SEND")
        guard managerBluetooth.peripheral.canSendWriteWithoutResponse else { return }
        
        let testData = wholeTestData.subdata(in: startingPoint..<startingPoint + dataPacketSize)
        self.startingPoint = startingPoint + dataPacketSize
        var responseType: CBCharacteristicWriteType
        if withResponse == true {
            responseType = .withResponse
        } else {
            responseType = .withoutResponse
        }
        managerBluetooth.peripheral.writeValue(testData,
                                               for: managerBluetooth.txCharacteristic,
                                               type: responseType)
    }
    
//    func sendTotalRecordedDataCount() {
//        var arrayCount = String(recSamples.count)
//        let arrayCountData = Data(arrayCount.utf8)
//        managerBluetooth.peripheral.writeValue(arrayCountData,
//                                               for: managerBluetooth.arrayCountCharacteristic,
//                                               type: .withResponse)
//    }
    
    func sendArrayCount() {
        var arrayCount = String(calculatedArraySize(packetSize: dataPacketSize))
        let arrayCountData = Data(arrayCount.utf8)
        managerBluetooth.peripheral.writeValue(arrayCountData,
                                               for: managerBluetooth.arrayCountCharacteristic,
                                               type: .withResponse)
    }
    
    func sendPacketSize() {
        var packetSize = String(self.dataPacketSize)
        let packetSizeData = Data(packetSize.utf8)
        managerBluetooth.peripheral.writeValue(packetSizeData,
                                               for: managerBluetooth.packetSizeCharacteristic,
                                               type: .withResponse)
    }
    
    //MARK: Cypress testing method
    func cypressSendArray() {
            let byteCount = 508
            let withResponse = false
            
            //print("TRYING TO SEND \(byteCount) bytes.")
            guard managerBluetooth.peripheral.canSendWriteWithoutResponse else {
                //print("Can't send write without response!")
                return
            }
            let newConnectionInterval = Date().timeIntervalSince(transferStartTime as Date)
            let connectionDelta = newConnectionInterval - lastConnectionInterval
            connectionIntervals.append(connectionDelta)
            let kbitSpeed = ((Double(byteCount) / averageConnectionInterval) * 8) / 1000
            print("Average ConnectionInterval: \(round(averageConnectionInterval * 10000) / 10000)")
        
            //SPEED RESULT
            print("Possible transfer speed: \(round(kbitSpeed * 10) / 10) kbps")

            lastConnectionInterval = newConnectionInterval
            
            let testArray = Array(repeating: Float32(1), count: byteCount / 4)
            print("Sending \(connectionIntervals.count - 1) byte")
            var testData = Data()
            testData.append(UInt8(1))
            let dataFiller = Data(bytes: testArray, count: byteCount)
            testData.append(dataFiller)
            managerBluetooth.peripheral.writeValue(testData,
                                                   for: managerBluetooth.rxCharacteristic,
                                                   type: .withoutResponse)
        }
    
    
    func sendPeripheralModeSwitcher() {
        var packetSize = String(0)
        let packetSizeData = Data(packetSize.utf8)
        managerBluetooth.peripheral.writeValue(packetSizeData,
                                               for: managerBluetooth.packetSizeCharacteristic,
                                               type: .withResponse)
    }
    
    func sendingTimerStart() {
        testDataTimer = Timer(timeInterval: 0.001,
                              target: self,
                              selector: #selector(sendNextDataPiece),
                              userInfo: nil,
                              repeats: true)
        RunLoop.current.add(testDataTimer, forMode: .common)
    }
    
    @objc func sendNextDataPiece() {
        guard !sendingIsComplete else { return }
        switch selectedSendingType {
        case .l2Cap:
            l2CapDataSend()
        case .withResponse:
            charDataSend(withResponse: true)
        case .withoutResponse:
            charDataSend(withResponse: false)
        }
        print(startingPoint)
        if wholeTestData.count - startingPoint <= 0 {
            testDataTimer.invalidate()
            startingPoint = 0
            testArray = []
            print("DATA SENT")
            sendingIsComplete = true
        }
    }
    
    @objc func printTimerCount() {
        print(testDataTimer.timeInterval)
    }
 
    @IBAction func sliderScroll(_ sender: UISlider) {
        self.dataPacketSize = Int(sender.value)
        packetSizeLabel.text = "\(String(Int(sender.value))) bytes"
    }
    
    
    
    @IBAction func l2CapSelect(_ sender: UIButton) {
        self.selectedSendingType = .l2Cap
        sendingTypeSelectionUpdate(sendingType: .l2Cap)
    }
    
    @IBAction func withResponseSelect(_ sender: UIButton) {
        self.selectedSendingType = .withResponse
        sendingTypeSelectionUpdate(sendingType: .withResponse)
    }
    
    @IBAction func withoutResponseSelect(_ sender: UIButton) {
        self.selectedSendingType = .withoutResponse
        sendingTypeSelectionUpdate(sendingType: .withoutResponse)
    }
 
    @IBAction func connectDisconnect(_ sender: UIButton) {
        self.connectToDevice()
    }
    
    @IBAction func scanPeripherals(_ sender: UIButton) {
        managerBluetooth.centralManager.scanForPeripherals(withServices: [petriloquistCBUUID])
        print("Start scan for peripherals...")
    }
    
    @IBAction func startTalk(_ sender: UIButton) {
        print("START SENDING")
        guard managerBluetooth.peripheral.state == .connected else { return }
        sendingIsComplete = false
        //Preparation data for sending
        fillTestFloatArray(totalSize: calculatedArraySize(packetSize: dataPacketSize))
        wholeTestData = Data(buffer: UnsafeBufferPointer(start: &testArray, count: testArray.count))
        print(wholeTestData.count)
        
        //UIupdate
        uiUpdate(uiState: .dataAreSending)
        
        //Begin sending cycle - continuation after characteristic respond in CentralBluetoothManager
        sendPeripheralModeSwitcher()
    }
    
    @IBAction func stopTalk(_ sender: UIButton) {

    }
    
    @IBAction func showTalkMode(_ sender: UIButton) {
        let mainStoryboard: UIStoryboard = UIStoryboard(name: "TalkMode", bundle: nil)
        guard let desVC = mainStoryboard.instantiateViewController(withIdentifier: "TalkModeViewController") as? TalkModeViewController else {
            return
        }
        //managerBluetooth.uiDelegate = desVC
        show(desVC, sender: nil)
    }
    
    
    @objc func connectToDevice() {
        guard let peripheral = managerBluetooth.peripheral else {
            return
        }
        if peripheral.state == .connected {
            print("TRY TO DISCONNECT")
            managerBluetooth.disconnect(peripheral: managerBluetooth.peripheral)
        } else {
            print("TRY TO CONNECT")
            managerBluetooth.connect(peripheral: managerBluetooth.peripheral)
        }
    }
    
    func selectionClear() {
        l2CapButtonView.backgroundColor = UIColor(hexString: "90DAE4")
        responseButtonView.backgroundColor = UIColor(hexString: "90DAE4")
        noResponseButtonView.backgroundColor = UIColor(hexString: "90DAE4")
    }
    
    func sendingTypeSelectionUpdate(sendingType: sendingType) {
        switch sendingType {
            
        case .l2Cap:
            sendingTypeLabel.text = "L2Cap"
            packetSizeSlider.value = 176
            packetSizeLabel.text = "\(String(176)) bytes"
            packetSizeSlider.maximumValue = 2048
            selectionClear()
            l2CapButtonView.backgroundColor = UIColor(hexString: "1D4C6E")
        case .withResponse:
            sendingTypeLabel.text = "Response"
            packetSizeSlider.value = 176
            packetSizeLabel.text = "\(String(176)) bytes"
            packetSizeSlider.maximumValue = Float(maxValueResponse)
            selectionClear()
            responseButtonView.backgroundColor = UIColor(hexString: "1D4C6E")
        case .withoutResponse:
            sendingTypeLabel.text = "NoResponse"
            packetSizeSlider.value = 176
            packetSizeLabel.text = "\(String(176)) bytes"
            packetSizeSlider.maximumValue = Float(maxValueNoResponse)
            selectionClear()
            noResponseButtonView.backgroundColor = UIColor(hexString: "1D4C6E")
        }
    }
    
    func uiUpdate(uiState: uiState) {
        switch uiState {
        case .firstLoad:
            connectView.alpha = 0.3
            headerView.alpha = 0.3
            headerView.isUserInteractionEnabled = false
            packetSizeLabel.text = "\(String(176)) bytes"
            talkButtonView.alpha = 0.3
            talkButtonView.isUserInteractionEnabled = false
            speedResultView.alpha = 0.3
        case .afterSearch:
            connectView.alpha = 1
        case .afterConnect:
            connectLabel.text = "DISCONNECT"
            scanView.alpha = 0.3
            scanView.isUserInteractionEnabled = false
        case .afterChannelOpening:
            talkButtonView.alpha = 1
            talkButtonView.isUserInteractionEnabled = true
            headerView.alpha = 1
            headerView.isUserInteractionEnabled = true
        case .afterDisconnect:
            scanView.alpha = 1
            scanView.isUserInteractionEnabled = true
            connectLabel.text = "CONNECT"
            talkButtonView.alpha = 0.3
            talkButtonView.isUserInteractionEnabled = false
            headerView.alpha = 0.3
            headerView.isUserInteractionEnabled = false
            speedResultView.alpha = 0.3
            speedResultsLabel.text = ""
            talkButtonLabel.text = "SEND DATA"
            talkButton.isUserInteractionEnabled = true
        case .dataAreSending:
            talkButton.isUserInteractionEnabled = false
            talkButtonLabel.text = "SENDING DATA..."
            totalDataLabel.text = "TotalDataValue: \(wholeTestData.count) bytes, \(wholeTestData.count/dataPacketSize) packets"
            speedResultView.alpha = 0.3
            speedResultsLabel.text = ""
        case .dataHasSent:
            talkButtonLabel.text = "SEND DATA"
            talkButton.isUserInteractionEnabled = true
            speedResultView.alpha = 1
        }
    }
}

extension UIColor {
    convenience init(hexString: String, alpha: CGFloat = 1.0) {
        let hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if (hexString.hasPrefix("#")) {
            scanner.scanLocation = 1
        }
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }
    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format:"#%06x", rgb)
    }
    
    class func color(withData data:Data) -> UIColor {
        return NSKeyedUnarchiver.unarchiveObject(with: data) as! UIColor
    }
    
    func encode() -> Data {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
    
    static var random: UIColor {
        return UIColor(red: .random(in: 0...1),
                       green: .random(in: 0...1),
                       blue: .random(in: 0...1),
                       alpha: 1.0)
    }
    
}
