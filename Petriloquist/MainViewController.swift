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
        
    }
    
    var managerBluetooth = CentralBluetoothManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapConnect = UITapGestureRecognizer(target: self, action: #selector(connectToDevice))
        connectView.addGestureRecognizer(tapConnect)
        
//        let tapDownload = UITapGestureRecognizer(target: self, action: #selector(downloadVoice))
//        downloadView.addGestureRecognizer(tapDownload)
        
        fillTestFloatArray(totalSize: calculatedArraySize(packetSize: 176))
        wholeTestData = Data(buffer: UnsafeBufferPointer(start: &testArray, count: testArray.count))
        print(wholeTestData.count)
        
        managerBluetooth = CentralBluetoothManager.default
        
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
        switch sendingType {
        case l2Cap:
            l2CapDataSend()
        case charSendWithResponse:
            charDataSend(withResponse: true)
        case charSendWithoutResponse:
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
            managerBluetooth.disconnect(peripheral: managerBluetooth.peripheral)
            peripheralIsConnected = false
            print("DISCONNECTED")
        } else {
            managerBluetooth.connect(peripheral: managerBluetooth.peripheral)
            peripheralIsConnected = true
            print("CONNECTED")
        }
    }
    
    @objc func scanForPeripherals() {
        managerBluetooth.centralManager.scanForPeripherals(withServices: [petriloquistCBUUID])
        print("Start scan for peripherals...")
    }
}
