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

enum API {
  case getUploadURL(params: UploadParams)
  case upload(params: UploadParams, uploadResponse: UploadResponse)
}

extension API: TargetType {
  var baseURL: URL {
    switch self {
    case .getUploadURL(_):
      return URL(string: "https://upload-service-dot-client-dev-e301d.appspot.com")!
    case .upload(_, let response):
      return URL(string: response.urlString)!
    default:
      return websocketURL(isWS: false)
    }
  }
  
  var path: String {
    switch self {
    case .getUploadURL(_): return "/upload"
    case .upload(_, _): return ""
    }
  }
  
  var method: Moya.Method {
    switch self {
    case .getUploadURL(_): return .get
    case .upload(_, _): return .post
    }
  }
  
  var sampleData: Data {
    switch self {
    case .getUploadURL(_): return "".data(using: String.Encoding.utf8)!
    case .upload(_, _): return "".data(using: String.Encoding.utf8)!
    }
  }
  
  var task: Task {
    switch self {
    case .getUploadURL(let params):
      let urlParams = [
        "uid": params.uid,
        "uuid": params.encounterID,
        "ext": params.extension
      ]
      
      return Task.requestParameters(parameters: urlParams, encoding: URLEncoding.default)
    case .upload(let params, _):
      return Task.uploadFile(params.fileURL)
    default:
      break
    }
  }
  
  var headers: [String : String]? {
    switch self {
    case .getUploadURL(let params):
      return ["token": params.token]
    case .upload(let params, _):
      return ["token": params.token]
    default:
      return nil
    }
  }
}
