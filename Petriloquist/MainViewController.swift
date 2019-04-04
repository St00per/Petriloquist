//
//  MainViewController.swift
//  Petriloquist
//
//  Created by Kirill Shteffen on 29/03/2019.
//  Copyright © 2019 BlackBricks. All rights reserved.
//

import UIKit
import AVFoundation
import CoreBluetooth

class MainViewController: UIViewController, AVAudioRecorderDelegate {
    
    @IBOutlet weak var connectView: UIView!
    @IBOutlet weak var downloadView: UIView!
    
    @IBOutlet weak var listenButton: UIButton!
    @IBOutlet weak var talkButton: UIButton!
    
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var textedVoice: String = ""
    
    var testArray: [Float32] = []
    var wholeTestData = Data()
    var startingPoint = 0
    var dataPieceSize = 176
    var piecesCount = 0
    
    var testDataTimer: Timer!
    var peripheralIsConnected = false
    
    enum sendingType {
        case l2Cap
        case withResponse
        case withoutResponse
    }
    var selectedSendingType: sendingType = .l2Cap
    var managerBluetooth = CentralBluetoothManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        connectView.alpha = 0.5
        
        
//        let tapDownload = UITapGestureRecognizer(target: self, action: #selector(downloadVoice))
//        downloadView.addGestureRecognizer(tapDownload)
        
        fillTestFloatArray(totalSize: calculatedArraySize(packetSize: 176))
        wholeTestData = Data(buffer: UnsafeBufferPointer(start: &testArray, count: testArray.count))
        print(wholeTestData.count)
        
        managerBluetooth = CentralBluetoothManager.default
        managerBluetooth.viewController = self
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        //self.loadRecordingUI()
                    } else {
                        // failed to record!
                    }
                }
            }
        } catch {
            // failed to record!
        }
        
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            audioRecorder.delegate = self
            audioRecorder.record()
            //recordButton.setTitle("Tap to Stop", for: .normal)
        } catch {
            finishRecording(success: false)
        }
    }
    
    func calculatedArraySize(packetSize: Int) -> Int {
        var calculatedArraySize = 0
        let sizesRatio = 20000/packetSize
        calculatedArraySize = sizesRatio * packetSize
        if 20000 - calculatedArraySize > 500 {
            calculatedArraySize = (sizesRatio * packetSize) + packetSize
        }
        return calculatedArraySize
    }
    
    func fillTestFloatArray(totalSize: Int) {
        self.dataPieceSize = totalSize
        for _ in 1...totalSize {
            testArray.append(Float32(1))
        }
    }

    func finishRecording(success: Bool) {
        audioRecorder.stop()
        audioRecorder = nil
        
        if success {
            //recordButton.setTitle("Tap to Re-record", for: .normal)
        } else {
            //recordButton.setTitle("Tap to Record", for: .normal)
            // recording failed :(
        }
    }
 
    func l2CapDataSend() {
        print("TRY TO SEND")
        guard let ostream = managerBluetooth.channel?.outputStream else {
            return
        }
        if ostream.hasSpaceAvailable {
           let testData = wholeTestData.subdata(in: startingPoint..<startingPoint + dataPieceSize)
           self.startingPoint = startingPoint + dataPieceSize
            _ = testData.withUnsafeBytes { ostream.write($0, maxLength: testData.count)}
        }
    }
    
    func charDataSend(withResponse: Bool) {
        print("TRY TO SEND")
        guard managerBluetooth.peripheral.canSendWriteWithoutResponse else { return }
        let testData = wholeTestData.subdata(in: startingPoint..<startingPoint + dataPieceSize)
        self.startingPoint = startingPoint + dataPieceSize
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
    
    
    
    @objc func sendNextDataPiece() {
        switch selectedSendingType {
        case .l2Cap:
            l2CapDataSend()
        case .withResponse:
            charDataSend(withResponse: true)
        case .withoutResponse:
            charDataSend(withResponse: false)
        }
        if wholeTestData.count - startingPoint == 0 {
            testDataTimer.invalidate()
            startingPoint = 0
            print("DATA SENT")
        }
    }
    
    @objc func printTimerCount() {
        print(testDataTimer.timeInterval)
    }
    
    @IBAction func startListen(_ sender: UIButton) {
        print("LISTEN PRESSED")
    }
    
    @IBAction func stopListen(_ sender: UIButton) {
        print("Listen released")
    }
    
    @IBAction func connectDisconnect(_ sender: UIButton) {
            self.connectToDevice()
    }
 
    @IBAction func scanPeripherals(_ sender: UIButton) {
        self.scanForPeripherals()
    }
    
    @IBAction func startTalk(_ sender: UIButton) {
        guard managerBluetooth.peripheral != nil else { return }
        testDataTimer = Timer(timeInterval: 0.001, target: self, selector: #selector(sendNextDataPiece), userInfo: nil, repeats: true)
        RunLoop.current.add(testDataTimer, forMode: .common)
        //sendNextDataPiece()
    }
    
    @IBAction func stopTalk(_ sender: UIButton) {
        //testDataTimer.invalidate()
        //print("STOP RECORDING")
    }
    
    @objc func connectToDevice() {
        guard let peripheral = managerBluetooth.peripheral else {
            return
        }
        if peripheral.state == .connected {
            print("TRY TO DISCONNECT")
            managerBluetooth.disconnect(peripheral: managerBluetooth.peripheral)
            peripheralIsConnected = false
        } else {
            print("TRY TO CONNECT")
            managerBluetooth.connect(peripheral: managerBluetooth.peripheral)
            peripheralIsConnected = true
            
        }
    }
    
    func scanForPeripherals() {
        managerBluetooth.centralManager.scanForPeripherals(withServices: [petriloquistCBUUID])
        print("Start scan for peripherals...")
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
