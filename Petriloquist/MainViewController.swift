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
    
    @IBOutlet weak var l2CapButtonView: UIView!
    @IBOutlet weak var responseButtonView: UIView!
    @IBOutlet weak var noResponseButtonView: UIView!
    
    
    @IBOutlet weak var connectView: UIView!
    @IBOutlet weak var connectLabel: UILabel!
    
    @IBOutlet weak var downloadView: UIView!
    
    @IBOutlet weak var listenButton: UIButton!
    @IBOutlet weak var talkButton: UIButton!
    @IBOutlet weak var talkButtonLabel: UILabel!
    @IBOutlet weak var talkButtonView: UIView!
    @IBOutlet weak var sendingTypeLabel: UILabel!
    
    @IBOutlet weak var listenView: UIView!
    @IBOutlet weak var headerView: UIView!
    
    @IBOutlet weak var speedResultView: UIView!
    @IBOutlet weak var speedResultsLabel: UILabel!
    @IBOutlet weak var packetSizeSlider: UISlider!
    @IBOutlet weak var packetSizeLabel: UILabel!
    
    
    
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var audioInput: TempiAudioInput!
    //let engine = AVAudioEngine()
    //var textedVoice: String = ""
    
    var testArray: [Float32] = []
    var recSamples: [Float] = []
    var wholeTestData = Data()
    var startingPoint = 0
    var dataPacketSize = 176
    var maxValueResponse = 0
    var maxValueNoResponse = 0
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
        connectView.alpha = 0.3
        headerView.alpha = 0.3
        headerView.isUserInteractionEnabled = false
        listenView.alpha = 0.3
//        talkButtonView.alpha = 0.3
//        talkButtonView.isUserInteractionEnabled = false
        speedResultView.alpha = 0.3

        let audioInputCallback: TempiAudioInputCallback = { (timeStamp, numberOfFrames, samples) -> Void in
            self.recSamples.append(contentsOf: samples)
            //print("Callback is called")
        }
        
        audioInput = TempiAudioInput(audioInputCallback: audioInputCallback, sampleRate: 44100, numberOfChannels: 1)
        
        managerBluetooth = CentralBluetoothManager.default
        managerBluetooth.viewController = self
    }
    
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
    
    func fillTestFloatArray(totalSize: Int) {
        
        for _ in 1...totalSize {
            testArray.append(Float32(1))
        }
    }

//    func recordedSamples() {
//        let input = engine.inputNode
//        let bus = 0
//        var samples: UnsafeMutablePointer<Float>?
//        input.installTap(onBus: bus, bufferSize: 512, format: input.inputFormat(forBus: bus)) { (buffer, time) -> Void in
//        samples = buffer.floatChannelData?[0]
//        rec = Data(buffer: UnsafeBufferPointer(start: samples, count: 512))
//            //audio callback, samples in samples[0]...samples[buffer.frameLength-1]
//        }
//        try! engine.start()
//
//
//    }
    
     func l2CapDataSend() {
        print("TRY TO SEND")
        guard let ostream = managerBluetooth.channel?.outputStream else {
            return
        }
        if ostream.hasSpaceAvailable {
           let testData = wholeTestData.subdata(in: startingPoint..<startingPoint + dataPacketSize)
           self.startingPoint = startingPoint + dataPacketSize
            _ = testData.withUnsafeBytes { ostream.write($0, maxLength: testData.count)}
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
    
    func sendingTimerStart() {
        testDataTimer = Timer(timeInterval: 0.001, target: self, selector: #selector(sendNextDataPiece), userInfo: nil, repeats: true)
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
        if wholeTestData.count - startingPoint <= 0 {
            testDataTimer.invalidate()
            startingPoint = 0
            testArray = []
            print("DATA SENT")
        }
    }
    
    @objc func printTimerCount() {
        print(testDataTimer.timeInterval)
    }
    
    @IBAction func startListen(_ sender: UIButton) {
        //print("LISTEN PRESSED")
    }
    
    @IBAction func stopListen(_ sender: UIButton) {
       // print("Listen released")
    }
    
    
    @IBAction func sliderScroll(_ sender: UISlider) {
        self.dataPacketSize = Int(sender.value)
        packetSizeLabel.text = String(Int(sender.value))
    }
    
    func selectionClear() {
        l2CapButtonView.backgroundColor = UIColor(hexString: "90DAE4")
        responseButtonView.backgroundColor = UIColor(hexString: "90DAE4")
        noResponseButtonView.backgroundColor = UIColor(hexString: "90DAE4")
    }
    
    @IBAction func l2CapSelect(_ sender: UIButton) {
        self.selectedSendingType = .l2Cap
        sendingTypeLabel.text = "L2Cap"
        packetSizeSlider.value = 176
        packetSizeLabel.text = String(176)
        packetSizeSlider.maximumValue = 2048
        selectionClear()
        l2CapButtonView.backgroundColor = UIColor(hexString: "1D4C6E")
    }
    
    @IBAction func withResponseSelect(_ sender: UIButton) {
        self.selectedSendingType = .withResponse
        sendingTypeLabel.text = "Response"
        packetSizeSlider.value = 176
        packetSizeLabel.text = String(176)
        packetSizeSlider.maximumValue = Float(maxValueResponse)
        selectionClear()
        responseButtonView.backgroundColor = UIColor(hexString: "1D4C6E")
    }
    
    @IBAction func withoutResponseSelect(_ sender: UIButton) {
        self.selectedSendingType = .withoutResponse
        sendingTypeLabel.text = "NoResponse"
        packetSizeSlider.value = 176
        packetSizeLabel.text = String(176)
        packetSizeSlider.maximumValue = Float(maxValueNoResponse)
        selectionClear()
        noResponseButtonView.backgroundColor = UIColor(hexString: "1D4C6E")
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
//        guard managerBluetooth.peripheral.state == .connected else { return }
        audioInput.startRecording()
//        talkButton.isUserInteractionEnabled = false
//        talkButtonLabel.text = "SENDING DATA..."
//        speedResultView.alpha = 0.3
//        speedResultsLabel.text = ""
//        fillTestFloatArray(totalSize: calculatedArraySize(packetSize: dataPacketSize))
//        wholeTestData = Data(buffer: UnsafeBufferPointer(start: &testArray, count: testArray.count))
        
//        wholeTestData = Data(buffer: UnsafeBufferPointer(start: recSamples, count: 512))
//        print(wholeTestData.count)
        //sendPacketSize()
    }
    
    @IBAction func stopTalk(_ sender: UIButton) {
        print("STOP RECORDING")
        audioInput.stopRecording()
        createFile(from: recSamples)
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
