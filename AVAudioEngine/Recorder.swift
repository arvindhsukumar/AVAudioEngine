//
//  Recorder.swift
//  AVAudioEngine
//
//  Created by arvindh on 07/08/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import UIKit

class Recorder: NSObject {
  @objc var engine: AVAudioEngine!
  @objc var downMixer: AVAudioMixerNode!
  @objc var isRecording: Bool = false
  @objc var converter: AVAudioConverter!
  
  override init() {
    super.init()
    setup()
  }
  
  @objc func setup() {
    engine = AVAudioEngine()
    makeEngineConnections()
  }
  
  @objc func makeEngineConnections() {
    let inputNode = engine.inputNode
    engine.connect(inputNode, to: engine.mainMixerNode, format: inputNode.outputFormat(forBus: 0))
  }
  
  @objc func startEngine() {
    do {
      try engine.start()
    }
    catch {
      print(error)
    }
  }
  
  @objc func startRecording(_ completion: @escaping (NSData) -> ()) {
    if !engine.isRunning {
      makeEngineConnections()
      startEngine()
    }
    
    let mixerNode: AVAudioNode = engine.inputNode
    let mixerFormat = mixerNode.outputFormat(forBus: 0)
    
    var outDesc = AudioStreamBasicDescription(
      mSampleRate: 44100, mFormatID: kAudioFormatFLAC, mFormatFlags: 0,
      mBytesPerPacket: 0, mFramesPerPacket: 0, mBytesPerFrame: 0,
      mChannelsPerFrame: 2, mBitsPerChannel: 0, mReserved: 0)
    let outFormat: AVAudioFormat = AVAudioFormat(streamDescription: &outDesc)!
    
    if let c = AVAudioConverter(from: mixerFormat, to: outFormat) {
      self.converter = c
    }
    else {
      print("error creating converter")
    }
    
    mixerNode.installTap(onBus: 0, bufferSize: 1024, format: mixerFormat, block: {
      [weak self] (buffer, time) in
      guard let this = self else {
        return
      }
      
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
        let data: NSData = NSData(bytes: mData, length: Int(audioBuffer.mDataByteSize))
        print("recorded data of length \(data.length)")
        completion(data)
      }
      else {
        print("no data in buffer")
      }
      
    })
    
    isRecording = true
  }
  
  @objc func stopRecording() {
    if self.isRecording {
      self.engine.inputNode.removeTap(onBus: 0)
      self.engine.stop()
      self.isRecording = false
    }
    
  }
}
