//
//  Helper.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 15/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

class Helper {
  static func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory
  }

  static func getTemporaryDirectory() -> URL {
    return FileManager.default.temporaryDirectory
  }

  static func recordingURL(forEncounterID encounterID: String) -> URL {
    return Helper.getTemporaryDirectory().appendingPathComponent("recording-\(encounterID).flac")
  }
}

extension Helper {
  static func addBytesProcessed(_ ack: Ack, isFirstAck:Bool, recordingInfo: RecordingInfo) {
    var bytesProcessed = Defaults[.bytesProcessed]
    var bytesProcessedForEncounter = bytesProcessed[recordingInfo.encounterID] ?? []
    
    if isFirstAck {
      bytesProcessedForEncounter.append(ack.bytes)
    }
    else {
      let lastIndex = bytesProcessedForEncounter.count - 1
      bytesProcessedForEncounter[lastIndex] = ack.bytes
    }
    
    bytesProcessed[recordingInfo.encounterID] = bytesProcessedForEncounter
    Defaults[.bytesProcessed] = bytesProcessed
  }
  
  static func bytesProcessed(recordingInfo: RecordingInfo) -> Int {
    let bytesProcessed = Defaults[.bytesProcessed]
    let bytesProcessedForEncounter = bytesProcessed[recordingInfo.encounterID] ?? []
    return bytesProcessedForEncounter.reduce(0) { (memo, bytes) -> Int in
      return memo + bytes
    }
  }
  
  static func addBytesSaved(_ data: Data, recordingInfo: RecordingInfo) {
    var bytesSaved = Defaults[.bytesSaved]
    var bytesSavedForEncounter = bytesSaved[recordingInfo.encounterID] ?? 0
    bytesSavedForEncounter += data.count
    bytesSaved[recordingInfo.encounterID] = bytesSavedForEncounter
    Defaults[.bytesSaved] = bytesSaved
  }
  
  static func bytesSaved(recordingInfo: RecordingInfo) -> Int {
    let bytesSaved = Defaults[.bytesSaved]
    return bytesSaved[recordingInfo.encounterID] ?? 0
  }
}

