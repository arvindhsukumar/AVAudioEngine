//
//  WebsocketManager.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 13/09/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import UIKit
import SocketRocket

let kIPAddress: String = "192.168.9.150"

typealias WebsocketOnConnect = ((_ connected: Bool) -> Void)
typealias WebsocketOnClose = ((_ wasClean: Bool) -> Void)

class WebsocketManager: NSObject {
  var socket: SRWebSocket?
  var onConnect: WebsocketOnConnect?
  var onStop: WebsocketOnClose?
  var accessToken: String
  var currentRecordingInfo: RecordingInfo?
  var shouldStop: Bool = false
  
  init(accessToken: String) {
    self.accessToken = accessToken
    super.init()
  }
  
  func connect(info: RecordingInfo, _ onConnect:@escaping WebsocketOnConnect) {
    if let socket = socket, let currentRecordingInfo = currentRecordingInfo, socket.readyState == .OPEN, info == currentRecordingInfo {
      // Socket is already open, with no change in the recording, so no need to connect again
      onConnect(true)
      return
    }
    
    self.currentRecordingInfo = info
    self.onConnect = onConnect
    
    let session = URLSession.shared
    let url = URL(string: "http://\(kIPAddress):8080/streaming")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    
    let task = session.dataTask(with: request) {
      [weak self] (data, response, error) in
      
      guard let this = self else {
        return
      }
      
      if let _ = error {
        this.onConnect?(false)
        this.onConnect = nil
      }
      else {
        this.createSocket()
      }
    }
    
    task.resume()
  }
  
  @objc func createSocket() {
    let url = URL(string: "ws://\(kIPAddress):8080/streaming")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    socket = SRWebSocket(urlRequest: request, protocols: ["chat", "superchat"], allowsUntrustedSSLCertificates: true)
    socket?.delegate = self
    
    socket?.open()
  }
  
  @objc func send(data: NSData) {
    guard let socket = socket, socket.readyState == .OPEN else {
      return
    }
    
    socket.send(data)
  }
  
  @objc func send(message: String) {
    guard let socket = socket, socket.readyState == .OPEN else {
      return
    }
    
    socket.send(message)
  }
  
  @objc func start() {
    guard let info = currentRecordingInfo else {
      return
    }
    
    send(message: "{\"type\": \"start\",\"encounter_id\": \"\(info.encounterID)\",\"user_id\": \"\(info.userID)\",\"recording_number\": 0}")
  }
  
  @objc func stop(_ onStop: @escaping WebsocketOnClose) {
    self.onStop = onStop
    self.shouldStop = true
    
    if let socket = socket, socket.readyState == .OPEN {
      sendStopMessage()
    }
    else {
      onStop(false)
      self.onStop = nil
      self.shouldStop = false
    }
  }
  
  @objc func sendStopMessage() {
    self.send(message: "{\"type\": \"stop\"}")
  }
  
}

extension WebsocketManager: SRWebSocketDelegate {
  func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
    print("Websocket received message: \(message)")
  }
  
  func webSocketDidOpen(_ webSocket: SRWebSocket!) {
    onConnect?(true)
    onConnect = nil
  }
  
  func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
    print("Websocket failed with error: \(error.localizedDescription)")
  }
  
  func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
    print("Websocket closed with code: \(code), reason: \(reason)")
    
    if shouldStop {
      // Call onStop only if stop message was sent
      onStop?(wasClean)
      onStop = nil
      shouldStop = false
    }
    currentRecordingInfo = nil
  }
  
  
}
