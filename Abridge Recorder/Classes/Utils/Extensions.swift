//
//  Extensions.swift
//  AVAudioEngine
//
//  Created by arvindh on 24/07/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import Foundation
import AVFoundation

@objc extension NSData {
  convenience init(buffer: AVAudioBuffer) {
    let audioBuffer = buffer.audioBufferList.pointee.mBuffers
    self.init(bytes: audioBuffer.mData, length: Int(audioBuffer.mDataByteSize))
  }
}
