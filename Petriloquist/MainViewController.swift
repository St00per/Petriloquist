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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapConnect = UITapGestureRecognizer(target: self, action: #selector(connectToDevice))
        connectView.addGestureRecognizer(tapConnect)
        
        let tapDownload = UITapGestureRecognizer(target: self, action: #selector(downloadVoice))
        downloadView.addGestureRecognizer(tapDownload)
        
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
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record()
            
            //recordButton.setTitle("Tap to Stop", for: .normal)
        } catch {
            finishRecording(success: false)
        }
    }
    
    static func readFile(url: URL) -> [Float] {
        guard
            let file = try? AVAudioFile(forReading: url),
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false) else {
                print("Error in readFile! returning empty array...")
                return []
        }
        let bufferCapacity: AVAudioFrameCount = 1024
        var readed: AVAudioFrameCount = bufferCapacity
        var array = [Float]()
        while readed == bufferCapacity {
            if let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferCapacity) {
                do {
                    try file.read(into: buf)
                } catch {
                    print(url.lastPathComponent)
                    print("Error: \(error.localizedDescription)")
                }
                readed = buf.frameLength
                // this makes a copy, you might not want that
                if let bufChannelData = buf.floatChannelData {
                    array.append(contentsOf: Array(UnsafeBufferPointer(start: bufChannelData[0], count:Int(readed))))
                }
            }
        }
        return array
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
//    func sendVoiceToDevice(recordedVoice: String) {
//        let peripheral = CentralBluetoothManager.default.foundDevices[0]
//        let peripheralCharacteristic = CentralBluetoothManager.default.petriloquistCharacteristic
//        var transferCharacteristic: CBMutableCharacteristic? = CentralBluetoothManager.default.transferCharacteristic
//        let sendedVoice = "VOICE DATA"
//        peripheral.writeValue(sendedVoice,
//                              for: peripheralCharacteristic,
//                              type: CBCharacteristicWriteType.withoutResponse)
//    }
    
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
