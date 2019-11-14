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

let kAccessToken = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjI1MDgxMWNkYzYwOWQ5MGY5ODE1MTE5MWIyYmM5YmQwY2ViOWMwMDQiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiQXJ2aW5kaCBTdWt1bWFyIiwiaXNzIjoiaHR0cHM6Ly9zZWN1cmV0b2tlbi5nb29nbGUuY29tL2NsaWVudC1kZXYtZTMwMWQiLCJhdWQiOiJjbGllbnQtZGV2LWUzMDFkIiwiYXV0aF90aW1lIjoxNTczNDc2MzY0LCJ1c2VyX2lkIjoiVTN4RGZUdUQ1ZGZHdll5M3F0U0FSVTkwVldaMiIsInN1YiI6IlUzeERmVHVENWRmR3ZZeTNxdFNBUlU5MFZXWjIiLCJpYXQiOjE1NzM0NzYzNjQsImV4cCI6MTU3MzQ3OTk2NCwiZW1haWwiOiJhcnZpbmRoQGFicmlkZ2UuYWkiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJhcnZpbmRoQGFicmlkZ2UuYWkiXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.Td2o5rgW7XykRGPW_xdun5bTzIy2zH1UT1N8YKOfZdk1-sjVRwV7nWA6FXOP4UXHBwVtegwG79sMr9CBWoTly7mjxpSNTylwSJWE4Dp0IfTcKt25hUJwt6IW3sQKzB4kYUvaCHdvnpXqmahm52p9p9rCTQLL9L0MknwD1pEegSf8cn9q1r6FDELWp33RiRp2UNKD984kHwTr_3jn6m6j_NUpRuXeauXukCX8HW59vLDR3LoC-4aLHy1hXZcwbJg3hCOFkp4qsGVrY4e8E2zU86kmORVAwx9JKYOd3CA8Iykx_dFzB8PUOIMKIoVKBaSHxKgKFBIfeP_7L1aPX5ZitQ"

@objc(RecordingManager)
class RecordingManager: NSObject {
  var recorder: Recorder!
  var websocketManager: WebsocketManager<WebSocket>!
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
      self.isConnectionInterrupted = true
      self.wasConnectionInterrupted = true
    }
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
    websocketManager = WebsocketManager(accessToken: kAccessToken)
    
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
      self?.recorder.stopRecording()
      self?.currentRecordingInfo = nil
      
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
}
