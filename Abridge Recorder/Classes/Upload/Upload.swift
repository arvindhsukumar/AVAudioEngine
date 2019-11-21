//
//  Upload.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 14/11/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import Foundation

struct UploadParams {
  var uid: String
  var encounterID: String
  var token: String
  var `extension`: String
  
  var filePath: String {
    return fileURL.path
  }
  
  var fileURL: URL {
    return Helper.recordingURL(forEncounterID: encounterID)
  }
}

struct UploadResponse: Codable {
  enum CodingKeys: String, CodingKey {
    case url
  }
  
  var urlString: String!
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.urlString = try container.decode(String.self, forKey: .url)
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(urlString, forKey: .url)
  }
}
