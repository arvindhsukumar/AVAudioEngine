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

let kAccessToken = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImZhMWQ3NzBlZWY5ZWFhNjU0MzY1ZGE5MDhjNDIzY2NkNzY4ODkxMDUiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiQXJ2aW5kaCBTdWt1bWFyIiwiaXNzIjoiaHR0cHM6Ly9zZWN1cmV0b2tlbi5nb29nbGUuY29tL2NsaWVudC1kZXYtZTMwMWQiLCJhdWQiOiJjbGllbnQtZGV2LWUzMDFkIiwiYXV0aF90aW1lIjoxNTcxMjEwMjMzLCJ1c2VyX2lkIjoiVTN4RGZUdUQ1ZGZHdll5M3F0U0FSVTkwVldaMiIsInN1YiI6IlUzeERmVHVENWRmR3ZZeTNxdFNBUlU5MFZXWjIiLCJpYXQiOjE1NzEyMTAyMzMsImV4cCI6MTU3MTIxMzgzMywiZW1haWwiOiJhcnZpbmRoQGFicmlkZ2UuYWkiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJhcnZpbmRoQGFicmlkZ2UuYWkiXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.IeLTusRF7ptc7M-I3BT7ichlhv7r79ENAQkmBQVpr1Q5fC9AnnqROQTMzKKPjjuyq70Ny7_poDEqJ6H7RgQOIh1W0Nl8tKtCItYXvlScPNyUXchWufs4_h0H7vXJr264qP7JuvkSiveQgMpK-eYfwT9MB9CzSsy0bQGD3kJue6cTkb2NlpbG6rst5cmS8dSk-Yp3UZfZeTG1steZEw6uC4KxK_yHfA9AG7sPixNOZiqM_gm5zl9qWk45NTAe92JZkXn0JOFWql56de0CZOm4N4hjct3MEc1NaIF13wyLZTifl0be-cwk5zBJsttji02v9Iy-IQO42yYafHpHNJwcOg"

class RecordingManager: NSObject {
  var recorder: Recorder!
  var websocketManager: WebsocketManager!
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
    
  }
  
  func setupWebsocket() {
    websocketManager = WebsocketManager(accessToken: kAccessToken)
  }
  
  func setupRecorder() {
    recorder = Recorder()
    
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
  
  func startRecording(_ info: [String: AnyHashable]) {
    // TODO: Show spinner
    let info = RecordingInfo(info: info)
    currentRecordingInfo = info
    
    websocketManager.connect(info: info) {
      [weak self](_) in
      // TODO: Hide spinner
      self?.websocketManager.start()
      self?.recorder.startRecording(info: info) { (data) in
        self?.websocketManager.send(data: data)
      }
    }
  }
  
  func pauseRecording() {
    recorder.pauseRecording()
    Defaults[.pauseTimestamp] = Date()
  }
  
  func resumeRecording() {
    guard let info = currentRecordingInfo else {
      return
    }
    
    let date = Date()
    
    let resume = {
      [weak self] in
      self?.recorder.resumeRecording()
    }
    
    if let pauseTimestamp = Defaults[.pauseTimestamp], date.timeIntervalSince(pauseTimestamp) > 30 {
      // If the pause duration is more than 30 seconds, we need to connect to the websocket again.
      // TODO: Need to refresh access token?
      websocketManager.connect(info: info) { (_) in
        resume()
      }
    }
    else {
      resume()
    }
  }
  
  func stopRecording() {
    websocketManager.stop {
      [weak self] (_) in
      self?.recorder.stopRecording()
      Defaults[.pauseTimestamp] = nil
      self?.currentRecordingInfo = nil
    }
  }
}
