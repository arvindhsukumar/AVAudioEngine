//
//  Stopwatch.swift
//  Abridge-Recorder
//
//  Created by arvindhsukumar on 22/11/19.
//

import Foundation

class Stopwatch {
  var timeElapsed: TimeInterval = 0
  var isRunning: Bool = false

  func start() {
    if isRunning {
      return
    }
    
    timeElapsed = 0
    isRunning = true
  }
    
  func stop() {
    timeElapsed = 0
    isRunning = false
  }
  
  func increment(time: TimeInterval) {
    timeElapsed += time
  }
}
