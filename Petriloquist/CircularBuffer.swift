//
//  CircularBuffer.swift
//  Petriloquist
//
//  Created by Kirill Shteffen on 08/04/2019.
//  Copyright © 2019 BlackBricks. All rights reserved.
//

import AVFoundation

public struct RingBuffer<T> {
    private var array: [T?]
    private var readIndex = 0
    private var writeIndex = 0
    
    public init(count: Int) {
        array = [T?](repeating: nil, count: count)
    }
    
    /* Returns false if out of space. */
    @discardableResult public mutating func write(element: T) -> Bool {
        if !isFull {
            array[writeIndex % array.count] = element
            writeIndex += 1
            return true
        } else {
            return false
        }
    }
    
    /* Returns nil if the buffer is empty. */
    public mutating func read() -> T? {
        if !isEmpty {
            let element = array[readIndex % array.count]
            readIndex += 1
            return element
        } else {
            return nil
        }
    }
    
    fileprivate var availableSpaceForReading: Int {
        return writeIndex - readIndex
    }
    
    public var isEmpty: Bool {
        return availableSpaceForReading == 0
    }
    
    fileprivate var availableSpaceForWriting: Int {
        return array.count - availableSpaceForReading
    }
    
    public var isFull: Bool {
        return availableSpaceForWriting == 0
    }
}

class ToneGenerator {
    
    fileprivate var toneUnit: AudioUnit? = nil
    static let sampleRate = 16000
    static let amplitude: Float = 1.0
    static let frequency: Float = 440
    
    /// Theta is changed over time as each sample is provided.
    static var theta: Float = 0.0
 
    private let renderCallback: AURenderCallback = { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
        
        print("CALLBACK IS CALLED")
        guard let abl = UnsafeMutableAudioBufferListPointer(ioData) else { return 0 }
        let buffer = abl[0]
        let pointer: UnsafeMutableBufferPointer<Float32> = UnsafeMutableBufferPointer(buffer)
        for frame in 0..<inNumberFrames {
            let pointerIndex = pointer.startIndex.advanced(by: Int(frame))
            pointer[pointerIndex] = sin(theta) * amplitude
            theta += 2.0 * Float(M_PI) * frequency / Float(sampleRate)
        }
        return noErr
    }
    
    init() {
        setupAudioUnit()
    }
    
    deinit {
        stop()
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
        var streamFormat = AudioStreamBasicDescription(mSampleRate: Float64(ToneGenerator.sampleRate),
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
        print("GENERATOR STARTED")
        var status: OSStatus
        status = AudioUnitInitialize(toneUnit!)
        status = AudioOutputUnitStart(toneUnit!)
        assert(status == noErr)
        
    }
    
    func stop() {
        AudioOutputUnitStop(toneUnit!)
        AudioUnitUninitialize(toneUnit!)
    }
    
}
