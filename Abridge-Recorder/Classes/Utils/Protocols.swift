//
//  Protocols.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 25/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import Foundation
import Starscream

public protocol Socket: class {
  var isConnected: Bool {get}
  var onConnect: (() -> Void)? {get set}
  var onDisconnect: ((Error?) -> Void)? {get set}
  var onText: ((String) -> Void)? {get set}
  
  func connect()
  func disconnect()
  func write(data: Data)
  func write(string: String)
  
  static func make(request: URLRequest, protocols: [String]?) -> Self
}
