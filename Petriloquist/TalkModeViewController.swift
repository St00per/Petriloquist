//
//  TalkModeViewController.swift
//  Petriloquist
//
//  Created by Kirill Shteffen on 11/04/2019.
//  Copyright © 2019 BlackBricks. All rights reserved.
//

import UIKit
import CoreBluetooth
import AVFoundation

class TalkModeViewController: UIViewController, BluetoothManagerUIDelegate {
 
    @IBOutlet weak var l2CapButtonView: UIView!
    @IBOutlet weak var responseButtonView: UIView!
    @IBOutlet weak var noResponseButtonView: UIView!
    @IBOutlet weak var scanView: UIView!
    @IBOutlet weak var connectView: UIView!
    @IBOutlet weak var connectLabel: UILabel!
    @IBOutlet weak var listenButton: UIButton!
    @IBOutlet weak var talkButton: UIButton!
    @IBOutlet weak var talkButtonLabel: UILabel!
    @IBOutlet weak var talkButtonView: UIView!
    @IBOutlet weak var sendingTypeLabel: UILabel!
    @IBOutlet weak var listenView: UIView!
    @IBOutlet weak var headerView: UIView!
    
    @IBOutlet weak var packetSizeSlider: UISlider!
    @IBOutlet weak var packetSizeLabel: UILabel!
    
    enum sendingType {
        case l2Cap
        case withResponse
        case withoutResponse
    }
    var speedResult: String = ""
    var audioInput: TempiAudioInput!
    var recSamples: [Float] = []
    var wholeTestData = Data()
    var startingPoint = 0
    var dataPacketSize = 176
    var maxValueResponse = 0
    var maxValueNoResponse = 0
    var testDataTimer: Timer!
    var sendingIsComplete = false
    var selectedSendingType: sendingType = .l2Cap
    var managerBluetooth = CentralBluetoothManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        uiUpdate(uiState: .firstLoad)
        //Append recording callback
        let audioInputCallback: TempiAudioInputCallback = { (timeStamp, numberOfFrames, samples) -> Void in
            
            self.recSamples.append(contentsOf: samples)
            self.wholeTestData = Data(buffer: UnsafeBufferPointer(start: &self.recSamples, count: self.recSamples.count))
            //print(self.recSamples.count)
        }
        audioInput = TempiAudioInput(audioInputCallback: audioInputCallback, sampleRate: 4000, numberOfChannels: 1)
        
        //Bluetooth manager init
        managerBluetooth = CentralBluetoothManager.default
        managerBluetooth.talkModeViewController = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        managerBluetooth.uiDelegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        guard managerBluetooth.peripheral.state == .connected else { return }
        managerBluetooth.disconnect(peripheral: managerBluetooth.peripheral)
    }
    
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
    
    func l2CapDataSend() {
        print("TRY TO VOICE SEND")
        guard let ostream = managerBluetooth.channel?.outputStream else {
            return
        }
        if ostream.hasSpaceAvailable {
            if startingPoint + dataPacketSize < wholeTestData.count {
                let testData = wholeTestData.subdata(in: startingPoint..<startingPoint + dataPacketSize)
                _ = testData.withUnsafeBytes { ostream.write($0, maxLength: testData.count)}
                self.startingPoint = startingPoint + dataPacketSize
            }
        }
    }
    
    func charDataSend(withResponse: Bool) {
        print("TRY TO VOICE SEND")
        guard managerBluetooth.peripheral.canSendWriteWithoutResponse else { return }
        if startingPoint + dataPacketSize < wholeTestData.count {
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
    }
    
    func sendTotalRecordedDataCount() {
        var arrayCount = String(recSamples.count)
        let arrayCountData = Data(arrayCount.utf8)
        managerBluetooth.peripheral.writeValue(arrayCountData,
                                               for: managerBluetooth.arrayCountCharacteristic,
                                               type: .withResponse)
    }
    
    func sendArrayCount() {
        var arrayCount = String(calculatedArraySize(packetSize: dataPacketSize))
        let arrayCountData = Data(arrayCount.utf8)
        managerBluetooth.peripheral.writeValue(arrayCountData,
                                               for: managerBluetooth.arrayCountCharacteristic,
                                               type: .withResponse)
    }
    
    func sendPeripheralStateSwitcher() {
        var packetSize = String(1)
        let packetSizeData = Data(packetSize.utf8)
        managerBluetooth.peripheral.writeValue(packetSizeData,
                                               for: managerBluetooth.packetSizeCharacteristic,
                                               type: .withResponse)
    }
    
    func sendPacketSize() {
        var packetSize = String(self.dataPacketSize)
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
        
        switch selectedSendingType {
        case .l2Cap:
            l2CapDataSend()
        case .withResponse:
            charDataSend(withResponse: true)
        case .withoutResponse:
            charDataSend(withResponse: false)
        }
//        if wholeTestData.count - startingPoint <= 0 {
//            testDataTimer.invalidate()
//            startingPoint = 0
//
//            print("DATA SENT")
//        }
    }
    
    func close() {
        managerBluetooth.uiDelegate = nil
        self.dismiss(animated: true, completion: nil)
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
            
            talkButtonLabel.text = "TALK"
            talkButton.isUserInteractionEnabled = true
        case .dataAreSending:
//            talkButton.isUserInteractionEnabled = false
            talkButtonLabel.text = "SENDING..."
            
        case .dataHasSent:
            talkButtonLabel.text = "TALK"
            talkButton.isUserInteractionEnabled = true
            
        }
    }
    
    @IBAction func closeTalkMode(_ sender: UIButton) {
        close()
    }
    
    @IBAction func startListen(_ sender: UIButton) {
        //print("LISTEN PRESSED")
    }
    
    @IBAction func stopListen(_ sender: UIButton) {
        // print("Listen released")
    }
    
    @IBAction func sliderScroll(_ sender: UISlider) {
        self.dataPacketSize = Int(sender.value)
        packetSizeLabel.text = "\(String(Int(sender.value))) bytes"
    }
    
    func selectionClear() {
        l2CapButtonView.backgroundColor = UIColor(hexString: "90DAE4")
        responseButtonView.backgroundColor = UIColor(hexString: "90DAE4")
        noResponseButtonView.backgroundColor = UIColor(hexString: "90DAE4")
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
        print("START RECORDING")
        guard managerBluetooth.peripheral.state == .connected else { return }
        //Start mic recording
        audioInput.startRecording()
   
        //UIupdate
        uiUpdate(uiState: .dataAreSending)
        
        //Begin sending cycle - continuation after characteristic respond in CentralBluetoothManager
        sendPeripheralStateSwitcher()
        
        //AudioUnit implemented playback
        //        do {
        //            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        //            try AVAudioSession.sharedInstance().setActive(true)
        //        } catch {
        //            print(error)
        //        }
        //        toneGenerator.start()
    }
    
    @IBAction func stopTalk(_ sender: UIButton) {
        print("STOP RECORDING")
        //Record and send testing
        audioInput.stopRecording()
        testDataTimer.invalidate()
        uiUpdate(uiState: .dataHasSent)
        sendTotalRecordedDataCount()
    }
    
    //Create file from recorded PCM float data
    func createFile(from data: [Float], temporary: Bool = false, filename: String = "TestRecord.wav") -> URL? {
        var urlString: String
        if temporary {
            urlString = filename
            if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(urlString) {
                try? FileManager.default.removeItem(at: url)
            }
        } else {
            urlString = filename
        }
        let recordSettings: [String : Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true
            ] as [String : Any]
        guard
            let audioUrl = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(urlString)),
            let file = try? AVAudioFile(forWriting: audioUrl, settings: recordSettings, commonFormat: AVAudioCommonFormat.pcmFormatFloat32, interleaved: true),
            let format = AVAudioFormat(settings: recordSettings) else {
                print("CreateFile error. Returning nil...")
                return nil
        }
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(data.count))!
        for i in 0..<data.count {
            if let floatChannelDataPointee = outputBuffer.floatChannelData?.pointee {
                floatChannelDataPointee[i] = data[i]
            }
        }
        outputBuffer.frameLength = AVAudioFrameCount(data.count)
        
        do {
            try file.write(from: outputBuffer)
        } catch {
            print("error:", error.localizedDescription)
        }
        
        return audioUrl
    }
    
}
