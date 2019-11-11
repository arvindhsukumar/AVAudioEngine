//
//  SocketAPI.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 29/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import Foundation

let kIPAddress: String = "192.168.1.133"
let isLocal: Bool = false

func websocketURL(isWS: Bool) -> URL {
  var urlComponents: URLComponents = URLComponents()
  if isLocal {
    urlComponents.host = kIPAddress
    urlComponents.port = 8080
    urlComponents.scheme = "http"
  }
  else {
    urlComponents.host = "streaming-service-dot-client-dev-e301d.appspot.com"
    urlComponents.scheme = "https"
  }
  
  if isWS {
    urlComponents.scheme = "ws"
  }
  
  return urlComponents.url!
}
