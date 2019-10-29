//
//  WebsocketManager.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 13/09/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import UIKit
import Starscream
import Moya

typealias WebsocketOnConnect = ((_ connected: Bool) -> Void)
typealias WebsocketOnClose = ((_ wasClean: Bool) -> Void)

class WebsocketManager<S: NSObject>: NSObject where S: Socket {
  var socket: S?
  var onConnect: WebsocketOnConnect?
  var onStop: WebsocketOnClose? // For when user stops recording
  var onClose: WebsocketOnClose? // For when websocket is closed for _any_ reason
  var accessToken: String
  var currentRecordingInfo: RecordingInfo?
  let provider: MoyaProvider<SocketAPI>!
  
  init(accessToken: String, provider: MoyaProvider<SocketAPI> = MoyaProvider<SocketAPI>()) {
    self.accessToken = accessToken
    self.provider = provider
    super.init()
  }
  
  func connect(info: RecordingInfo, _ onConnect:@escaping WebsocketOnConnect) {
    if let socket = socket, socket.isConnected {
      if let currentRecordingInfo = currentRecordingInfo, info != currentRecordingInfo {
        // Recording has changed
        self.currentRecordingInfo = info
      }
      
      // Socket is already open, so no need to connect again
      onConnect(true)
      return
    }
    
    self.currentRecordingInfo = info
    self.onConnect = onConnect
    
    provider.request(SocketAPI.streaming(accessToken)) {
      [weak self] (result) in
      
      guard let this = self else {
        return
      }
      
      if let _ = result.error {
        this.onConnect?(false)
        this.onConnect = nil
      }
      else {
        this.createSocket()
      }
    }
  }
  
  @objc func createSocket() {
    let url = URL(string: "ws://\(kIPAddress):8080/streaming")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    socket = S.make(request: request, protocols: ["chat", "superchat"])
    socket?.onConnect = {
      [weak self] in
      print("Socket connected")
      self?.onConnect?(true)
      self?.onConnect = nil
    }
    
    socket?.onDisconnect = {
      [weak self] error in
      print("Socket disconnected")
      
      let wasClean = error == nil
      self?.onStop?(wasClean)
      self?.onClose?(wasClean)
      self?.onStop = nil
      self?.currentRecordingInfo = nil
    }
    
    socket?.onText = {
      [weak self] text in
      print("Received message: \(text)")
    }
    
    socket?.connect()
  }
  
  @objc func send(data: NSData) {
    guard let socket = socket, socket.isConnected else {
      return
    }
    
    socket.write(data: data as Data)
  }
  
  @objc func send(message: String) {
    guard let socket = socket, socket.isConnected else {
      return
    }
    
    socket.write(string: message)
  }
  
  @objc func start() {
    guard let info = currentRecordingInfo else {
      return
    }
    
    send(message: "{\"type\": \"start\",\"encounter_id\": \"\(info.encounterID)\",\"user_id\": \"\(info.userID)\",\"recording_number\": 0}")
  }
  
  @objc func stop(_ onStop: @escaping WebsocketOnClose) {
    self.onStop = onStop
    
    if let socket = socket, socket.isConnected {
      sendStopMessage()
    }
    else {
      onStop(false)
      self.onStop = nil
    }
  }
  
  @objc func sendStopMessage() {
    self.send(message: "{\"type\": \"stop\"}")
  }
}

extension WebSocket: Socket {
  static func make(request: URLRequest, protocols: [String]?) -> Self {
    return WebSocket(request: request, protocols: protocols, stream: FoundationStream()) as! Self
  }

}
