//
//  Recorder.swift
//  AVAudioEngine
//
//  Created by arvindh on 07/08/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftyUserDefaults

public struct RecordingInfo: Equatable {
  public var encounterID: String
  public var userID: String
  public var recordingNumber: Int
  public var token: String
  
  public init(info: [String: AnyHashable]) {
    self.encounterID = info["encounterID"]?.base as! String
    self.userID = info["userID"]?.base as! String
    self.recordingNumber = 0
    self.token = info["token"]?.base as? String ?? ""
  }
  
  mutating public func incrementRecordingNumber() {
    self.recordingNumber += 1
  }
  
  public var uploadParams: UploadParams {
    return UploadParams(uid: userID, encounterID: encounterID, token: token, extension: "flac")
  }
  
  static public func ==(lhs: RecordingInfo, rhs: RecordingInfo) -> Bool {
    return (lhs.encounterID == rhs.encounterID) && (lhs.userID == rhs.userID)
  }
}

public typealias OnRecord = (NSData) -> Void

public class Recorder: NSObject {
  @objc public var engine: AVAudioEngine!
  @objc public var downMixer: AVAudioMixerNode!
  @objc public var isRecording: Bool = false
  @objc public var isPaused: Bool = false
  @objc public var converter: AVAudioConverter!
  public var writeFileHandle: FileHandle?
  public var currentRecordingInfo: RecordingInfo?
  
  public var onRecord: OnRecord?
  
  override init() {
    super.init()
    setup()
  }
  
  @objc public func setup() {
    engine = AVAudioEngine()
    downMixer = AVAudioMixerNode()
    engine.attach(downMixer)
    makeEngineConnections()
    engine.prepare()
  }
  
  @objc public func makeEngineConnections() {
    let inputNode = engine.inputNode
    engine.connect(inputNode, to: downMixer, format: inputNode.outputFormat(forBus: 0))
    
    let downMixerFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)
    engine.connect(downMixer, to: engine.mainMixerNode, format: downMixerFormat)
  }
  
  public func startEngine() {
    do {
      try engine.start()
    }
    catch {
      print(error)
    }
  }
  
  public func startRecording(info: RecordingInfo) {
    currentRecordingInfo = info
    
    let mixerNode: AVAudioNode = downMixer
    let mixerFormat = mixerNode.outputFormat(forBus: 0)
    
    var outDesc = AudioStreamBasicDescription()
    outDesc.mSampleRate = 44100
    outDesc.mChannelsPerFrame = 1
    outDesc.mFormatID = kAudioFormatFLAC
    outDesc.mFramesPerPacket = 1152
    outDesc.mBitsPerChannel = 24
    outDesc.mBytesPerPacket = 0
    
    let outFormat: AVAudioFormat = AVAudioFormat(streamDescription: &outDesc)!
    
    if self.converter == nil {
      if let c = AVAudioConverter(from: mixerFormat, to: outFormat) {
        self.converter = c
        self.converter.primeMethod = AVAudioConverterPrimeMethod.none
      }
      else {
        print("error creating converter")
      }
    }
    
    do {
      let fileURL = Helper.recordingURL(forEncounterID: info.encounterID)
      createFileIfNeeded()
      writeFileHandle = try FileHandle(forWritingTo: fileURL)
    }
    catch {
      print(error)
    }
        
    mixerNode.installTap(onBus: 0, bufferSize: 1152 * 8, format: mixerFormat, block: {
      [weak self] (buffer, time) in
      guard let this = self else {
        return
      }
      
      DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
        let outBuffer = AVAudioCompressedBuffer(
          format: outFormat,
          packetCapacity: 8,
          maximumPacketSize: this.converter.maximumOutputPacketSize)
        
        let inputBlock : AVAudioConverterInputBlock = {
          inNumPackets, outStatus in
          outStatus.pointee = AVAudioConverterInputStatus.haveData;
          return buffer; // fill and return input buffer
        }
        
        // Conversion loop
        var outError: NSError? = nil
        this.converter.convert(to: outBuffer, error: &outError, withInputFrom: inputBlock)
        
        let audioBuffer = outBuffer.audioBufferList.pointee.mBuffers
        if let mData = audioBuffer.mData {
          let length = Int(audioBuffer.mDataByteSize)
          let data: NSData = NSData(bytes: mData, length: length)
          DispatchQueue.main.async {
            this.writeDataToDisk(data as Data)
            
            if let recordingInfo = this.currentRecordingInfo {
              Helper.addBytesSaved(data as Data, recordingInfo: recordingInfo)
            }
            
            this.onRecord?(data)
          }
        }
        else {
          print("no data in buffer")
        }
      }
      
    })
    
    if !engine.isRunning {
      makeEngineConnections()
      startEngine()
    }
    
    isRecording = true    
  }
  
  func writeDataToDisk(_ data: Data) {
    guard let fileHandle = self.writeFileHandle else {
      return
    }
    
    createFileIfNeeded()
    
    fileHandle.seekToEndOfFile()
    fileHandle.write(data)
  }
  
  
  
  func createFileIfNeeded() {
    guard let info = currentRecordingInfo else {
      return
    }
    
    let fileManager = FileManager.default
    let fileURL = Helper.recordingURL(forEncounterID: info.encounterID)
    let fileExists = fileManager.fileExists(atPath: fileURL.path)
    
    if !fileExists {
      fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
    }
  }
  
  @objc public func pauseRecording() {
    self.engine.pause()
    isPaused = true
  }
  
  @objc public func resumeRecording() {
    startEngine()
    isPaused = false
  }
  
  @objc public func stopRecording() {
    if self.isRecording {
      let mixerNode: AVAudioNode = downMixer
      mixerNode.removeTap(onBus: 0)
      engine.stop()
      isRecording = false
      isPaused = false
      writeFileHandle?.closeFile()
      currentRecordingInfo = nil
    }
  }
}
