//
//  SocketAPI.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 29/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import Foundation
import Moya
import Alamofire

let kIPAddress: String = "192.168.1.133"

enum SocketAPI {
  case streaming(String)
}

extension SocketAPI: TargetType {
  var baseURL: URL {
    return URL(string: "http://\(kIPAddress):8080")!
  }
  
  var path: String {
    switch self {
    case .streaming(_): return "/streaming"
    }
  }
  
  var method: Moya.Method {
    switch self {
    case .streaming(_): return .get
    }
  }
  
  var sampleData: Data {
    switch self {
    case .streaming(_): return "".data(using: String.Encoding.utf8)!
    }
  }
  
  var task: Task {
    return Task.requestPlain
  }
  
  var headers: [String : String]? {
    switch self {
    case .streaming(let accessToken): return ["Authorization": "Bearer \(accessToken)"]
    }
  }
}
