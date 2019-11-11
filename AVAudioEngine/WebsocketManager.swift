//
//  WebsocketManager.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 13/09/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import UIKit
import Starscream

typealias WebsocketOnConnect = ((_ connected: Bool, _ shouldStart: Bool) -> Void)
typealias WebsocketOnClose = ((_ wasClean: Bool) -> Void)
typealias WebsocketOnMessage = ((_ message: String) -> Void)

class WebsocketManager<S: NSObject>: NSObject where S: Socket {
  var socket: S?
  var onConnect: WebsocketOnConnect?
  var onStop: WebsocketOnClose? // For when user stops recording
  var onClose: WebsocketOnClose? // For when websocket is closed for _any_ reason
  var onMessage: WebsocketOnMessage?
  var accessToken: String
  var currentRecordingInfo: RecordingInfo?
  var firstAck: Ack?
  
  init(accessToken: String) {
    self.accessToken = accessToken
    super.init()
  }
  
  func connect(info: RecordingInfo, _ onConnect:@escaping WebsocketOnConnect) {
    if let socket = socket, socket.isConnected {
      var shouldStart = false
      if let currentRecordingInfo = currentRecordingInfo, info != currentRecordingInfo {
        // Recording has changed
        self.currentRecordingInfo = info
        shouldStart = true
      }
      
      // Socket is already open, so no need to connect again
      onConnect(true, shouldStart)
      return
    }
    
    self.currentRecordingInfo = info
    self.onConnect = onConnect
    self.createSocket()
  }
  
  @objc func createSocket() {
    let url = websocketURL(isWS: false).appendingPathComponent("streaming")

    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    socket = S.make(request: request, protocols: ["chat", "superchat"])
    socket?.onConnect = {
      [weak self] in
      print("Socket connected")
      guard let this = self else {
        return
      }
      
      this.onConnect?(true, true)
      this.onConnect = nil
    }
    
    socket?.onDisconnect = {
      [weak self] error in
      print("Socket disconnected")
      
      let wasClean = error == nil
      self?.onStop?(wasClean)
      self?.onClose?(wasClean)
      self?.onStop = nil
      self?.currentRecordingInfo = nil
      self?.firstAck = nil
    }
    
    socket?.onText = {
      [weak self] text in

      guard let this = self else {
        return
      }
      
      if let ack = Ack(message: text), let recordingInfo = this.currentRecordingInfo {
        let isFirstAck = (this.firstAck == nil)
        Helper.addBytesProcessed(ack, isFirstAck: isFirstAck, recordingInfo: recordingInfo)
        this.firstAck = ack
      }
    
      this.onMessage?(text)
    }
    
    socket?.connect()
  }
  
  @objc func send(data: NSData) {
    guard let socket = socket, socket.isConnected else {
      return
    }
    
    DispatchQueue.main.async {
      socket.write(data: data as Data)
    }
  }
  
  @objc func send(message: String) {
    guard let socket = socket, socket.isConnected else {
      return
    }
    
    DispatchQueue.main.async {
      socket.write(string: message)
    }    
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

class Ack {
  var bytes: Int
  
  init?(message: String) {
    guard let json = try? JSONSerialization.jsonObject(with: message.data(using: String.Encoding.utf8)!, options: []) as? [String: AnyHashable] else {
      return nil
    }
    
    self.bytes = json["bytes"] as? Int ?? 0
  }
}
