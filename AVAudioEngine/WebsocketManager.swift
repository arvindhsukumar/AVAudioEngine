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

class WebsocketManager: NSObject {
  var socket: SRWebSocket?
  var onConnect: ((Bool) -> Void)?
  var accessToken: String
  
  @objc init(accessToken: String) {
    self.accessToken = accessToken
    super.init()
  }
  
  @objc func connect(_ onConnect:@escaping (Bool) -> Void) {
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
    socket?.send(data)
  }
  
  @objc func send(message: String) {
    socket?.send(message)
  }
  
  @objc func start() {
    send(message: "{\"type\": \"start\",\"encounter_id\": \"some_id\",\"user_id\": \"uid\",\"recording_number\": 0}")
  }
  
  @objc func stop() {
    sendStopMessage()
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
  }
  
  func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
    print("Websocket failed with error: \(error.localizedDescription)")
  }
  
  func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
    print("Websocket closed with code: \(code), reason: \(reason)")
  }
  
  
}
