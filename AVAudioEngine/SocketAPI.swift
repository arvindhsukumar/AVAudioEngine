//
//  SocketAPI.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 29/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import Foundation
import Moya

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

enum SocketAPI {
  case upload(params: UploadParams)
}

extension SocketAPI: TargetType {
  var baseURL: URL {
    switch self {
    case .upload(_):
      return URL(string: "https://upload-service-dot-client-dev-e301d.appspot.com")!
    default:
      return websocketURL(isWS: false)
    }
  }
  
  var path: String {
    switch self {
    case .upload(_): return "/upload"
    }
  }
  
  var method: Moya.Method {
    switch self {
    case .upload(_): return .post
    }
  }
  
  var sampleData: Data {
    switch self {
    case .upload(_): return "".data(using: String.Encoding.utf8)!
    }
  }
  
  var task: Task {
    switch self {
    case .upload(let params):
      let formData = [
        MultipartFormData(provider: MultipartFormData.FormDataProvider.file(params.url), name: "AVAudioEngineTest")
      ]
      
      let urlParams = [
        "uid": params.uid,
        "uuid": params.encounterID,
        "ext": params.extension
      ]
      
      return Task.uploadCompositeMultipart(formData, urlParameters: urlParams)
    default:
      break
    }
  }
  
  var headers: [String : String]? {
    return nil
  }
}
