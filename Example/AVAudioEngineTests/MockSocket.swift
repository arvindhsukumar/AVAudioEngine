//
//  MockSocket.swift
//  AVAudioEngineTests
//
//  Created by arvindhsukumar on 25/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import UIKit
@testable import AVAudioEngine

class MockSocket: NSObject, Socket {
  var _isConnected: Bool = false
  var isConnected: Bool {
    return _isConnected
  }
  
  var onConnect: (() -> Void)?
  
  var onDisconnect: ((Error?) -> Void)?
  
  var onText: ((String) -> Void)?
  
  func connect() {
    _isConnected = true
    onConnect?()
  }
  
  func disconnect() {
    _isConnected = false
    onDisconnect?(nil)
  }
  
  func write(data: Data) {
    
  }
  
  func write(string: String) {
    onText?("Received \(string)")
    
    if string.contains("stop") {
      disconnect()
    }
  }
  
  static func make(request: URLRequest, protocols: [String]?) -> Self {
    return MockSocket() as! Self
  }
}
