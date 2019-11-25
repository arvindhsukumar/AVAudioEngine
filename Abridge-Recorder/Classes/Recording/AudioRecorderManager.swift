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
import React

fileprivate enum Event: String {
  case recordingInterruptionStatusChanged = "interruptionStatusChanged"
  case recordingProgress = "recordingProgress"
  case recordingFinished = "recordingFinished"
  
  static var supportedEvents: [String] {
    let array: [Event] = [.recordingInterruptionStatusChanged, .recordingFinished, .recordingProgress]
    return array.map {$0.rawValue}
  }
}

@objc(AudioRecorderManager)
public class AudioRecorderManager: RCTEventEmitter {
  public var recorder: Recorder!
  public var websocketManager: WebsocketManager<WebSocket>!
  public var uploadManager: UploadManager! = UploadManager()
  public var reachability: Reachability!
  public var readFileHandle: FileHandle?

  public var isConfigChangePending: Bool = false
  public var isAudioInterrupted: Bool = false
  public var isConnectionInterrupted: Bool = false
  public var wasConnectionInterrupted: Bool = false
  var timer: RepeatingTimer?
  var stopwatch: Stopwatch = Stopwatch()
  
  public var isRecording: Bool {
    return recorder.isRecording
  }
  
  public var isPaused: Bool {
    return recorder.isPaused
  }
  
  public var currentRecordingInfo: RecordingInfo?
  
  public static let shared: AudioRecorderManager = {
    let manager = AudioRecorderManager()
    return manager
  }()
  
  public override class func requiresMainQueueSetup() -> Bool {
    return true
  }
  
  override init() {
    super.init()
    
    setupReachability()
    setupSession()
    setupWebsocket()
    setupRecorder()
  }
  
  public override func supportedEvents() -> [String]! {
    return Event.supportedEvents
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
    case .ended:
      isAudioInterrupted = false
    @unknown default:
      fatalError()
    }
    
    self.sendEventIfBridgeConnected(
      Event.recordingInterruptionStatusChanged,
      body: ["status": interruptionType.rawValue]
    )
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
  
  @objc public func prepareRecordingAtPath(_ path: String, _ info: [String: AnyHashable]) {
    let info = RecordingInfo(path: path, info: info)
    if isRecording {
      // Recording already happening, but another start request came in.
      return
    }
        
    currentRecordingInfo = info
  }
  
  @objc public func startRecording() {
    // TODO: Show spinner
    guard let info = self.currentRecordingInfo else {
      return
    }
    
    let fileURL = info.url
    try? FileManager.default.removeItem(at: fileURL)
    
    Defaults[.bytesProcessed] = [:]
    
    connectAndStartWebsocket {
      [weak self] in
      self?.startProgressTimer()
      self?.recorder.startRecording(info: info)
    }
  }
  
  @objc public func pauseRecording() {
    recorder.pauseRecording()
  }
  
  @objc public func resumeRecording() {
    connectAndStartWebsocket {
      [weak self] in
      self?.recorder.resumeRecording()
    }
  }
  
  @objc public func stopRecording() {
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
      this.stopProgressTimer()
      
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

extension AudioRecorderManager {
  func startProgressTimer() {
    if timer == nil {
      timer = RepeatingTimer(timeInterval: 1)
      timer?.eventHandler = {
        [weak self] timeinterval in
        self?.sendProgressUpdate()
      }
    }
    
    stopwatch.stop()
    stopwatch.start()
    
    timer?.resume()
  }
  
  func stopProgressTimer() {
    timer?.suspend()
    stopwatch.stop()
  }
  
  func sendProgressUpdate() {
    if !isRecording {
      return
    }
    
    self.sendEventIfBridgeConnected(
      Event.recordingProgress,
      body: ["currentTime": NSNumber(floatLiteral: stopwatch.timeElapsed)]
    )
    
    print("time elapsed: \(stopwatch.timeElapsed)")
  }
}

extension AudioRecorderManager {
  fileprivate func sendEventIfBridgeConnected(_ event: Event, body: [String: Any]) {
    if let _ = bridge {
      self.sendEvent(
        withName: event.rawValue,
        body: body
      )
    }
  }
}
