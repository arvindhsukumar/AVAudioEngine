//
//  Helper.swift
//  AVAudioEngineTests
//
//  Created by arvindhsukumar on 16/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import UIKit
@testable import AVAudioEngine

class Helper: NSObject {
  static var recordingInfo: RecordingInfo {
    return RecordingInfo(info: ["encounterID": "test-encounter", "userID": "1"])
  }
}
