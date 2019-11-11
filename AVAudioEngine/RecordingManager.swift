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

let kAccessToken = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImZhMWQ3NzBlZWY5ZWFhNjU0MzY1ZGE5MDhjNDIzY2NkNzY4ODkxMDUiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiQXJ2aW5kaCBTdWt1bWFyIiwiaXNzIjoiaHR0cHM6Ly9zZWN1cmV0b2tlbi5nb29nbGUuY29tL2NsaWVudC1kZXYtZTMwMWQiLCJhdWQiOiJjbGllbnQtZGV2LWUzMDFkIiwiYXV0aF90aW1lIjoxNTcxMzEzNDMwLCJ1c2VyX2lkIjoiVTN4RGZUdUQ1ZGZHdll5M3F0U0FSVTkwVldaMiIsInN1YiI6IlUzeERmVHVENWRmR3ZZeTNxdFNBUlU5MFZXWjIiLCJpYXQiOjE1NzEzMTM0MzAsImV4cCI6MTU3MTMxNzAzMCwiZW1haWwiOiJhcnZpbmRoQGFicmlkZ2UuYWkiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJhcnZpbmRoQGFicmlkZ2UuYWkiXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.WJPATxMPQhYzHIlRF_86nPa7YHPBKAVKbBHXFZXUFIAMToqSHgU-4022jWdNj9n3ML2tbVjKafbpqw-OjS6TPdcVuuz0HJ_pm72N3db17SXk9fc8MvvRSP29nppKXK3OiBBnAI9cUdL-bhIaQAlk-ld7ruBiJFEKDSX2ZGO-JnExZc7RfmfVQM6JXQbf6rMI7RKklKDWQZufl65aFcz8MXIZsGsoxs7HJEW6exOUtr28c2641aBfTV_xmjttn3SUbDLW7Jv4GeupJqFGYLaSgu8yXwY04-b42nYATjcG9iJUU7uh6uyVlXfkY7StZioRsxKXTyY7WjETqLDxlo0r8g"

@objc(RecordingManager)
class RecordingManager: NSObject {
  var recorder: Recorder!
  var websocketManager: WebsocketManager<WebSocket>!
  var readFileHandle: FileHandle?
  var isConfigChangePending: Bool = false
  var isSessionInterrupted: Bool = false
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
    
    setupSession()
    setupWebsocket()
    setupRecorder()
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
      isSessionInterrupted = true
      pauseRecording()
    case .ended:
      isSessionInterrupted = false
      resumeRecording()
    @unknown default:
      fatalError()
    }
  }
  
  func setupWebsocket() {
    websocketManager = WebsocketManager(accessToken: kAccessToken)
    websocketManager.onClose = {
      _ in 
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
      
      if (!this.isSessionInterrupted) {
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
    
    let fileURL = Helper.recordingURL(for: info.encounterID)
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
