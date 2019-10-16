//
//  Helper.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 15/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import Foundation

class Helper {
  static func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory
  }

  static func getTemporaryDirectory() -> URL {
    return FileManager.default.temporaryDirectory
  }

  static func recordingURL(for recordingID: String) -> URL {
    return Helper.getTemporaryDirectory().appendingPathComponent("recording-\(recordingID).flac")
  }
}
