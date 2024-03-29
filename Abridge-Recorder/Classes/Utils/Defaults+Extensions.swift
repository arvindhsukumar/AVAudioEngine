//
//  Defaults+Extensions.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 16/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

extension DefaultsKeys {
  static let pauseTimestamp = DefaultsKey<Date?>("pauseTimestamp")
  static let bytesProcessed = DefaultsKey<[String: [Int]]>("bytesProcessed", defaultValue: [:])
  static let bytesSaved = DefaultsKey<[String: Int]>("bytesSaved", defaultValue: [:])
}
