//
//  Stopwatch.swift
//  Abridge-Recorder
//
//  Created by arvindhsukumar on 22/11/19.
//

import Foundation

class Stopwatch {
  var startTime: Date?
  var timeElapsed: TimeInterval {
    guard let startTime = startTime else {
      return 0
    }
    
    return Date().timeIntervalSince(startTime)
  }
  var isRunning: Bool = false

  func start() {
    if isRunning {
      return
    }
    
    startTime = Date()
    isRunning = true
  }
    
  func stop() {
    startTime = nil
    isRunning = false
  }  
}
