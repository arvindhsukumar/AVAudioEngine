//
//  MockSocket.swift
//  AVAudioEngineTests
//
//  Created by arvindhsukumar on 17/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import Foundation
import Starscream

enum MockWebSocketError: Error {
  case failure
}

class MockWebSocket: WebSocket {
  override func connect() {
    isConnected = true
    self.onConnect?()
  }
  
  func disconnect() {
    isConnected = false
    self.onDisconnect?(nil)
  }
  
  func terminate() {
    isConnected = false
    self.onDisconnect?(MockWebSocketError.failure)
  }
}
