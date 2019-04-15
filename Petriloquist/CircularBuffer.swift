//
//  CircularBuffer.swift
//  Petriloquist
//
//  Created by Kirill Shteffen on 08/04/2019.
//  Copyright © 2019 BlackBricks. All rights reserved.
//

import AVFoundation

class SamplesPlayer {
    
    fileprivate var toneUnit: AudioUnit? = nil
    static let sampleRate = 4000
    static let amplitude: Float = 1.0
    static let frequency: Float = 440
    let path = Bundle.main.path(forResource: "TestRecord", ofType: "wav")
    static var shift: Int = 0
    static var playerIsStarted: Bool = false
    static var pcmArray: [Float] = [] {
        didSet {
            //print("PCM ARRAY COUNT: \(pcmArray.count)")
        }
    }
    
    /// Theta is changed over time as each sample is provided.
    private let renderCallback: AURenderCallback = { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
        
        guard let abl = UnsafeMutableAudioBufferListPointer(ioData) else { return 0 }
        let buffer = abl[0]
        let pointer: UnsafeMutableBufferPointer<Float32> = UnsafeMutableBufferPointer(buffer)
        
        var maximumIndex = Int((inNumberFrames - 1) + UInt32(shift))
        if maximumIndex < pcmArray.count {
            
            for index in 0..<inNumberFrames {
                let pointerIndex = pointer.startIndex.advanced(by: Int(index))
                pointer[pointerIndex] = pcmArray[Int(index + UInt32(shift))]
            }
            shift += Int(inNumberFrames - 1)
            return noErr
        }
        return noErr
    }
    
    init() {
        setupAudioUnit()
        
        //Test playback from bundle AudioFile
        //        let trackURL = URL(fileURLWithPath: path ?? "")
        //        SamplesPlayer.pcmArray = readFile(url: trackURL)
    }
    
    deinit {
        stop()
    }
    
    func readFile(url: URL) -> [Float] {
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
                    print("Error: (error.localizedDescription)")
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
    
    func setupAudioUnit() {
        
        // Configure the description of the output audio component we want to find:
        let componentSubtype: OSType
        #if os(OSX)
        componentSubtype = kAudioUnitSubType_DefaultOutput
        #else
        componentSubtype = kAudioUnitSubType_RemoteIO
        #endif
        var defaultOutputDescription = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                                                 componentSubType: componentSubtype,
                                                                 componentManufacturer: kAudioUnitManufacturer_Apple,
                                                                 componentFlags: 0,
                                                                 componentFlagsMask: 0)
        let defaultOutput = AudioComponentFindNext(nil, &defaultOutputDescription)
        
        var err: OSStatus
        
        // Create a new instance of it in the form of our audio unit:
        err = AudioComponentInstanceNew(defaultOutput!, &toneUnit)
        assert(err == noErr, "AudioComponentInstanceNew failed")
        
        // Set the render callback as the input for our audio unit:
        var renderCallbackStruct = AURenderCallbackStruct(inputProc: renderCallback as! AURenderCallback,
                                                          inputProcRefCon: nil)
        err = AudioUnitSetProperty(toneUnit!,
                                   kAudioUnitProperty_SetRenderCallback,
                                   kAudioUnitScope_Input,
                                   0,
                                   &renderCallbackStruct,
                                   UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        assert(err == noErr, "AudioUnitSetProperty SetRenderCallback failed")
        
        // Set the stream format for the audio unit. That is, the format of the data that our render callback will provide.
        var streamFormat = AudioStreamBasicDescription(mSampleRate: Float64(SamplesPlayer.sampleRate),
                                                       mFormatID: kAudioFormatLinearPCM,
                                                       mFormatFlags: kAudioFormatFlagsNativeFloatPacked|kAudioFormatFlagIsNonInterleaved,
                                                       mBytesPerPacket: 4 /*four bytes per float*/,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 4*8,
            mReserved: 0)
        err = AudioUnitSetProperty(toneUnit!,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   0,
                                   &streamFormat,
                                   UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        assert(err == noErr, "AudioUnitSetProperty StreamFormat failed")
    }
    
    func start() {
        print("Samples Player STARTED. PCM ARRAY COUNT: \(SamplesPlayer.pcmArray.count)")
        var status: OSStatus
        status = AudioUnitInitialize(toneUnit!)
        status = AudioOutputUnitStart(toneUnit!)
        assert(status == noErr)
    }
    
    func stop() {
        print("Samples Player STOPPED. PCM ARRAY COUNT: \(SamplesPlayer.pcmArray.count)")
        AudioOutputUnitStop(toneUnit!)
        AudioUnitUninitialize(toneUnit!)
        SamplesPlayer.shift = 0
        
    }
}
