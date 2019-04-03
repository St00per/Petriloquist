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
    
    
    var managerBluetooth = CentralBluetoothManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapConnect = UITapGestureRecognizer(target: self, action: #selector(connectToDevice))
        connectView.addGestureRecognizer(tapConnect)
        
        let tapDownload = UITapGestureRecognizer(target: self, action: #selector(downloadVoice))
        downloadView.addGestureRecognizer(tapDownload)
        
        fillTestFloatArray(forPacketSize: 176)
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
    
    func fillTestFloatArray(forPacketSize size: Int) {
        self.dataPieceSize = size
        for _ in 1...(size * 250) {
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
        guard let ostream = CentralBluetoothManager.default.channel?.outputStream else {
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
        guard CentralBluetoothManager.default.peripheral.canSendWriteWithoutResponse else { return }
        let testData = wholeTestData.subdata(in: startingPoint..<startingPoint + dataPieceSize)
        self.startingPoint = startingPoint + dataPieceSize
        var responseType: CBCharacteristicWriteType
        if withResponse == true {
            responseType = .withResponse
        } else {
            responseType = .withoutResponse
        }
        
        CentralBluetoothManager.default.peripheral.writeValue(testData,
                                                              for: CentralBluetoothManager.default.txCharacteristic,
                                                              type: responseType)
    }
    
    
    
    @objc func sendNextDataPiece() {
        l2CapDataSend()
        //charDataSend(withResponse: false)
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
        guard CentralBluetoothManager.default.peripheral != nil else { return }
        testDataTimer = Timer(timeInterval: 0.001, target: self, selector: #selector(sendNextDataPiece), userInfo: nil, repeats: true)
        RunLoop.current.add(testDataTimer, forMode: .common)
        //sendNextDataPiece()
    }
    
    @IBAction func stopTalk(_ sender: UIButton) {
        //testDataTimer.invalidate()
        //print("STOP RECORDING")
        
    }
    
    @objc func connectToDevice() {
        guard let peripheral = CentralBluetoothManager.default.peripheral else {
            return
        }
        if peripheral.state == .connected {
            CentralBluetoothManager.default.disconnect(peripheral: CentralBluetoothManager.default.peripheral)
            peripheralIsConnected = false
            print("DISCONNECTED")
        } else {
            CentralBluetoothManager.default.connect(peripheral: CentralBluetoothManager.default.peripheral)
            peripheralIsConnected = true
            print("CONNECTED")
        }
        
        //print("Start connecting...")
    }
    
    @objc func downloadVoice() {
        CentralBluetoothManager.default.centralManager.scanForPeripherals(withServices: [petriloquistCBUUID])
        //print("Start downloading...")
    }
}
