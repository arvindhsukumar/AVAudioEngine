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
  @objc var isPaused: Bool = false
  @objc var converter: AVAudioConverter!
  
  override init() {
    super.init()
    setup()
  }
  
  @objc func setup() {
    engine = AVAudioEngine()
    downMixer = AVAudioMixerNode()
    engine.attach(downMixer)
    makeEngineConnections()
    engine.prepare()
  }
  
  @objc func makeEngineConnections() {
    let inputNode = engine.inputNode
    engine.connect(inputNode, to: downMixer, format: inputNode.outputFormat(forBus: 0))
    
    let downMixerFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)
    engine.connect(downMixer, to: engine.mainMixerNode, format: downMixerFormat)
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
        self.converter.primeMethod = AVAudioConverterPrimeMethod.pre
      }
      else {
        print("error creating converter")
      }
    }
    
    let file = try! AVAudioFile(forWriting: URL(string: NSTemporaryDirectory().appending("mixerOutput.caf"))!, settings: mixerFormat.settings)
    
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
            try! file.write(from: buffer)
            completion(data)
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
  
  @objc func pauseRecording() {
    self.engine.pause()
    isPaused = true
  }
  
  @objc func resumeRecording() {
    startEngine()
    isPaused = false
  }
  
  @objc func stopRecording() {
    if self.isRecording {
      let mixerNode: AVAudioNode = downMixer
      mixerNode.removeTap(onBus: 0)
      self.engine.stop()
      self.isRecording = false
    }
  }
}
