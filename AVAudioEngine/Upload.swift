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
  
  var path: String {
    return url.path
  }
  
  var url: URL {
    return Helper.recordingURL(forEncounterID: encounterID)
  }
}
