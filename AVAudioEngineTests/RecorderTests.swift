//
//  RecorderTests.swift
//  AVAudioEngineTests
//
//  Created by arvindhsukumar on 16/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

@testable import AVAudioEngine
import XCTest

class RecorderTests: XCTestCase {
  var recorder: Recorder!
  
  override func setUp() {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    recorder = Recorder()
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    Helper.deleteRecording()
  }
  
  func testStartRecording() {
    let expectation = XCTestExpectation(description: "Recorder should send data")
    let info = Helper.recordingInfo
    let recorder: Recorder = self.recorder
    
    let downMixer = try! XCTUnwrap(recorder.downMixer)
    
    recorder.startRecording(info: info) { data in
      XCTAssert(data.length > 0)
      
      let engine = try! XCTUnwrap(recorder.engine)
      
      XCTAssert(engine.isRunning)
      if #available(iOS 13.0, *) {
        XCTAssert(engine.attachedNodes.contains(downMixer))
      }
      XCTAssertNotNil(recorder.currentRecordingInfo)
      XCTAssertNotNil(recorder.converter)
      
      let fileHandle = try! XCTUnwrap(recorder.fileHandle)
      XCTAssertTrue(fileHandle.offsetInFile > 0)
      
      XCTAssertTrue(recorder.isRecording)
      
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testWriteDataToDisk() {
    let info = Helper.recordingInfo
    let recorder: Recorder = self.recorder
    recorder.currentRecordingInfo = info
    
    let fileURL = AVAudioEngine.Helper.recordingURL(for: info.encounterID)
    recorder.createFileIfNeeded()
    recorder.fileHandle = try! FileHandle(forWritingTo: fileURL)
    
    XCTAssertTrue(recorder.fileHandle!.offsetInFile == 0)
    
    let data = "Some text".data(using: String.Encoding.utf8)!
    recorder.writeDataToDisk(data)
    
    let fileManager = FileManager.default
    XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path))
    XCTAssertTrue(recorder.fileHandle!.offsetInFile > 0)
  }
  
  func testPauseRecording() {
    let expectation = XCTestExpectation(description: "Recorder should pause after starting")
    
    let info = Helper.recordingInfo
    let recorder: Recorder = self.recorder
    
    recorder.startRecording(info: info) { _ in
    }
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
      recorder.pauseRecording()
      
      XCTAssertTrue(recorder.isRecording)
      XCTAssertTrue(recorder.isPaused)
      
      let engine = try! XCTUnwrap(recorder.engine)
      XCTAssertFalse(engine.isRunning)
      
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testResumeRecording() {
    let expectation = XCTestExpectation(description: "Recorder should pause after starting")
    
    let info = Helper.recordingInfo
    let recorder: Recorder = self.recorder
    
    recorder.startRecording(info: info) { _ in
    }
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
      recorder.pauseRecording()
    }
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
      recorder.resumeRecording()
      
      XCTAssertTrue(recorder.isRecording)
      XCTAssertFalse(recorder.isPaused)
      
      let engine = try! XCTUnwrap(recorder.engine)
      XCTAssertTrue(engine.isRunning)
      
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testStopRecording() {
    let expectation = XCTestExpectation(description: "Recorder should pause after starting")
    
    let info = Helper.recordingInfo
    let recorder: Recorder = self.recorder
    
    recorder.startRecording(info: info) { _ in
    }
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
      recorder.stopRecording()
      
      let engine = try! XCTUnwrap(recorder.engine)
      XCTAssertFalse(engine.isRunning)
      
      XCTAssertFalse(recorder.isPaused)
      XCTAssertFalse(recorder.isRecording)
      XCTAssertNil(recorder.currentRecordingInfo)
      
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10)
  }
}
