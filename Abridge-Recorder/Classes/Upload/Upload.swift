//
//  Upload.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 14/11/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import Foundation

public struct UploadParams {
  var uid: String
  var encounterID: String
  var token: String
  var `extension`: String
  var path: String
  
  var fileURL: URL {
    return URL(fileURLWithPath: path)
  }
}

public struct UploadResponse: Codable {
  enum CodingKeys: String, CodingKey {
    case url
  }
  
  var urlString: String!
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.urlString = try container.decode(String.self, forKey: .url)
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(urlString, forKey: .url)
  }
}
