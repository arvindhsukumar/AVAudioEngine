//
//  RecordingManager.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 16/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftyUserDefaults
import Starscream
import Reachability

@objc(RecordingManager)
class RecordingManager: NSObject {
  var recorder: Recorder!
  var websocketManager: WebsocketManager<WebSocket>!
  var uploadManager: UploadManager! = UploadManager()
  var reachability: Reachability!
  var readFileHandle: FileHandle?

  var isConfigChangePending: Bool = false
  var isAudioInterrupted: Bool = false
  var isConnectionInterrupted: Bool = false
  var wasConnectionInterrupted: Bool = false

  var isRecording: Bool {
    return recorder.isRecording
  }
  
  var isPaused: Bool {
    return recorder.isPaused
  }
  
  var currentRecordingInfo: RecordingInfo?
  
  static let shared: RecordingManager = {
    let manager = RecordingManager()
    return manager
  }()
  
  override init() {
    super.init()
    
    setupReachability()
    setupSession()
    setupWebsocket()
    setupRecorder()
  }
  
  func setupReachability() {
    reachability = try! Reachability()
    reachability.whenReachable = {
      [unowned self] reachability in
      guard self.isRecording else {
        // If we're not recording, no need to consider interruptions
        return
      }
      
      if self.isConnectionInterrupted {
        self.currentRecordingInfo?.incrementRecordingNumber()
        self.connectAndStartWebsocket {
          [weak self] in
          // Nothing to do here, data will be sent over websocket in recorder's onRecord
        }
        self.isConnectionInterrupted = false
      }
    }
    
    reachability.whenUnreachable = {
      [unowned self] reachability in
      guard self.isRecording else {
        // If we're not recording, no need to consider interruptions
        return
      }
      
      self.isConnectionInterrupted = true
      self.wasConnectionInterrupted = true
    }
    
    try! reachability.startNotifier()
  }
  
  func setupSession() {
    let sessionInstance = AVAudioSession.sharedInstance()
      
    do {
      try sessionInstance.setCategory(AVAudioSession.Category.playAndRecord)
      
      let hwSampleRate = 44100.0;
      try sessionInstance.setPreferredSampleRate(hwSampleRate)
    
      let ioBufferDuration: TimeInterval = 0.0029;
      try sessionInstance.setPreferredIOBufferDuration(ioBufferDuration)
    
      NotificationCenter.default.addObserver(self, selector: #selector(self.handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: sessionInstance)
    
      try sessionInstance.setActive(true, options: [])
    }
    catch {
      print(error)
    }
  }
  
  @objc func handleInterruption(_ notification: Notification) {
    let userInfo = notification.userInfo
    let interruptionTypeValue: UInt = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
    let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue)!

    switch interruptionType {
    case .began:
      isAudioInterrupted = true
      pauseRecording()
    case .ended:
      isAudioInterrupted = false
      resumeRecording()
    @unknown default:
      fatalError()
    }
  }
  
  func setupWebsocket() {
    websocketManager = WebsocketManager()
    
    websocketManager.onMessage = {
      [weak self] text in
      
    }
    
    websocketManager.onClose = {
      [weak self] wasClean in
      
      guard let this = self else {
        return
      }
      
      if !wasClean {
        if this.reachability.connection == .unavailable {
          
        }
      }
    }
  }
  
  func setupRecorder() {
    recorder = Recorder()
    recorder.onRecord = {
      [weak self] data in
      guard let this = self else {
        return
      }
      
      this.websocketManager.send(data: data)
    }
    
    NotificationCenter.default.addObserver(forName: NSNotification.Name.AVAudioEngineConfigurationChange, object: nil, queue: OperationQueue.main) {
      [weak self] (notification) in
      
      guard let this = self else {
        return
      }
      
      this.isConfigChangePending = true
      
      if (!this.isAudioInterrupted) {
        this.recorder.makeEngineConnections()
      }
      else {
        print("Session is interrupted, deferring changes")
      }
    }
  }
  
  @objc func prepareRecording(_ info: [String: AnyHashable]) {
    let info = RecordingInfo(info: info)
    if isRecording {
      // Recording already happening, but another start request came in.
      return
    }
        
    currentRecordingInfo = info
  }
  
  @objc func startRecording() {
    // TODO: Show spinner
    guard let info = self.currentRecordingInfo else {
      return
    }
    
    let fileURL = Helper.recordingURL(forEncounterID: info.encounterID)
    try? FileManager.default.removeItem(at: fileURL)
    
    Defaults[.bytesProcessed] = [:]
    
    connectAndStartWebsocket {
      [weak self] in
      self?.recorder.startRecording(info: info)
    }
  }
  
  @objc func pauseRecording() {
    recorder.pauseRecording()
  }
  
  @objc func resumeRecording() {
    connectAndStartWebsocket {
      [weak self] in
      self?.recorder.resumeRecording()
    }
  }
  
  @objc func stopRecording() {
    recorder.pauseRecording()
    readFileHandle?.seekToEndOfFile()
    readFileHandle?.closeFile()
    readFileHandle?.readabilityHandler = nil
    websocketManager.stop {
      [weak self] (_) in
      guard let this = self else {
        return
      }
      
      this.recorder.stopRecording()
      
      if this.wasConnectionInterrupted {
        this.uploadFile()
      }
      
      this.currentRecordingInfo = nil

      // TODO: Cleanup stored data from UserDefaults
    }
  }
  
  func connectAndStartWebsocket(_ completion: @escaping () -> ()) {
    guard let info = currentRecordingInfo else {
      return
    }
    
    websocketManager.connect(info: info) {
      [unowned self](_, shouldStart) in
      if shouldStart {
        self.websocketManager.start()
      }
      
      completion()
    }
  }
  
  func uploadFile() {
    guard let recordingInfo = self.currentRecordingInfo else {
      return
    }
    
    uploadManager.upload(
      params: recordingInfo.uploadParams,
      progress: {
        [weak self] (progress) in
        
      },
      completion: {
        [weak self] error in
      }
    )
  }
}
