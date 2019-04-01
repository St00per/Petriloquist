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
    var testDataTimer = Timer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapConnect = UITapGestureRecognizer(target: self, action: #selector(connectToDevice))
        connectView.addGestureRecognizer(tapConnect)
        
        let tapDownload = UITapGestureRecognizer(target: self, action: #selector(downloadVoice))
        downloadView.addGestureRecognizer(tapDownload)
        
        testDataTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(sendNextSlice), userInfo: nil, repeats: true)
        
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
            //audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            //audioRecorder = try AVAudioRecorder(
            audioRecorder.delegate = self
            audioRecorder.record()
            
            //recordButton.setTitle("Tap to Stop", for: .normal)
        } catch {
            finishRecording(success: false)
        }
    }
    
    func fillTestFloatArray() {
        for index in 1...1024 {
            testArray.append(Float32(index))
        }
        wholeTestData = Data(buffer: UnsafeBufferPointer(start: &testArray, count: testArray.count))
    }
    
    @objc fileprivate func sendNextSlice() {
        if CentralBluetoothManager.default.isTXPortReady {
            CentralBluetoothManager.default.isTXPortReady = false
            var startingPoint = 0
            let dataPieceSize = 128
            
            let testData: Data = wholeTestData.subdata(in: startingPoint..<startingPoint + dataPieceSize)
            
            let peripheral = CentralBluetoothManager.default.foundDevices[0]
            guard let peripheralCharacteristic = CentralBluetoothManager.default.petriloquistCharacteristic else { return }
            
            //transfer data with standart write command
            peripheral.writeValue(testData,
                                  for: peripheralCharacteristic,
                                  type: CBCharacteristicWriteType.withoutResponse)
            //transfer data with L2CAPChannel
            guard let outputStream = CentralBluetoothManager.default.channel?.outputStream else {
                return
            }
            let bytesWritten = testData.withUnsafeBytes { outputStream.write($0, maxLength: dataPieceSize) }
            print("bytesWritten = \(bytesWritten)")
  
            
            startingPoint += dataPieceSize
            if startingPoint == dataPieceSize {
                startingPoint = 0
                testDataTimer.invalidate()
            }
        }
    }
    
    
    
    func convertBufferPCMDataToFloat() -> [Float] {
        let bufferCapacity: AVAudioFrameCount = 1024
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 1024, channels: 1, interleaved: false),
            let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferCapacity) else { return [0]}
        let bufChannelData = buf.floatChannelData
        
        guard let dataValue = bufChannelData?.pointee else { return [0]}
        let channelDataValueArray = stride(from: 0,
                                           to: Int(1024),
                                           by: 1).map{ dataValue[$0] }
        return channelDataValueArray
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
    
    //    func sendVoiceToChannel () {
    //        guard let ostream = CentralBluetoothManager.default.channel?.outputStream, let voice = "recorded voice", let data = voice.data(using: )  else {
    //            return
    //        }
    //        let bytesWritten =  data.withUnsafeBytes { ostream.write($0, maxLength: data.count) }
    //    }
    //
    func sendVoiceToDevice(recordedVoice: String) {
        let peripheral = CentralBluetoothManager.default.foundDevices[0]
        let peripheralCharacteristic = CentralBluetoothManager.default.petriloquistCharacteristic
        var transferCharacteristic: CBMutableCharacteristic? = CentralBluetoothManager.default.transferCharacteristic
        let sendedVoice = "VOICE DATA"
        //peripheral.writeValue(sendedVoice, for: peripheralCharacteristic, type: CBCharacteristicWriteType.withoutResponse)
    }
    
    func sendTextedVoiceToDevice() {
        guard let ostream = CentralBluetoothManager.default.channel?.outputStream else {
            return
        }
        let text = self.textedVoice
        let data = text.data(using: .utf8)
        let bytesWritten =  data?.withUnsafeBytes { ostream.write($0, maxLength: data?.count ?? 0) }
        
    }
    
    
    
    @IBAction func startListen(_ sender: UIButton) {
        print("LISTEN PRESSED")
    }
    
    @IBAction func stopListen(_ sender: UIButton) {
        print("Listen released")
    }
    
    
    @IBAction func startTalk(_ sender: UIButton) {
        startRecording()
        print("START RECORDING")
    }
    
    @IBAction func stopTalk(_ sender: UIButton) {
        finishRecording(success: true)
        print("STOP RECORDING")
    }
    
    @objc func connectToDevice() {
        print("Start connecting...")
    }
    
    @objc func downloadVoice() {
        print("Start downloading...")
    }
}
