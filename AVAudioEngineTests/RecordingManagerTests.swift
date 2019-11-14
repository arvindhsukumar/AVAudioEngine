//
//  RecordingManagerTests.swift
//  AVAudioEngineTests
//
//  Created by arvindhsukumar on 17/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import XCTest
@testable import AVAudioEngine
import SwiftyUserDefaults
import AVFoundation

class RecordingManagerTests: XCTestCase {
  var manager: RecordingManager!
  
  override func setUp() {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.manager = RecordingManager()
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    Helper.deleteRecording()
  }

  func testSetup() {
    let manager: RecordingManager = self.manager
    
    XCTAssertNotNil(manager.recorder)
    XCTAssertNotNil(manager.websocketManager)
    XCTAssertNotNil(manager.websocketManager.onClose)
    
    let session = AVAudioSession.sharedInstance()
    XCTAssert(session.category == .playAndRecord)
    XCTAssert(session.preferredSampleRate == 44100.0)
    XCTAssertEqual(session.preferredIOBufferDuration, 0.0029, accuracy: 0.00001)
  }
  
  func testStartRecording() {
    let expectation = XCTestExpectation()
    let manager: RecordingManager = self.manager
    let info = Helper.recordingInfo
    let infoDict = ["encounterID": info.encounterID, "userID": info.userID]
    manager.prepareRecording(infoDict)
    
    let currentRecording = try! XCTUnwrap(manager.currentRecordingInfo)
    manager.startRecording()
    
    XCTAssert(currentRecording.encounterID == infoDict["encounterID"])
    XCTAssert(currentRecording.userID == infoDict["userID"])
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
      XCTAssertTrue(manager.isRecording)
      XCTAssertFalse(manager.isPaused)
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testStartRecordingAfterAlreadyStarted() {
    let expectation = XCTestExpectation()
    let manager: RecordingManager = self.manager
    let info = Helper.recordingInfo
    let infoDict = ["encounterID": info.encounterID, "userID": info.userID]
    
    XCTAssertFalse(manager.isRecording)
    manager.prepareRecording(infoDict)
    manager.startRecording()
    
    let currentRecording = try! XCTUnwrap(manager.currentRecordingInfo)
        
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
      XCTAssertTrue(manager.isRecording, "Manager should be already recording")
      manager.prepareRecording(["encounterID": "another-encounter", "userID": info.userID])
      manager.startRecording()
      
      let newCurrentRecording = try! XCTUnwrap(manager.currentRecordingInfo)
      XCTAssertEqual(currentRecording, newCurrentRecording, "The new recording should have been ignored")
      
      XCTAssertTrue(manager.isRecording, "Manager should continue to record")

      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testStartRecordingAfterStopping() {
    let expectation = XCTestExpectation()
    let manager: RecordingManager = self.manager
    let info = Helper.recordingInfo
    let infoDict = ["encounterID": info.encounterID, "userID": info.userID]
    
    XCTAssertFalse(manager.isRecording)
    manager.prepareRecording(infoDict)
    manager.startRecording()
    
    let currentRecording = try! XCTUnwrap(manager.currentRecordingInfo)
        
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
      XCTAssertTrue(manager.isRecording, "Manager should be already recording")
      manager.stopRecording()
      XCTAssertFalse(manager.isRecording, "Manager should stop recording")
      
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
        manager.prepareRecording(["encounterID": "another-encounter", "userID": info.userID])
        manager.startRecording()

        let newCurrentRecording = try! XCTUnwrap(manager.currentRecordingInfo)
        XCTAssertNotEqual(currentRecording, newCurrentRecording, "The new recording should be different")
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
          XCTAssertTrue(manager.isRecording, "Manager should continue to record")
          expectation.fulfill()
        }
      }
    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testPauseRecording() {
    let expectation = XCTestExpectation()
    let manager: RecordingManager = self.manager
    let info = Helper.recordingInfo
    let infoDict = ["encounterID": info.encounterID, "userID": info.userID]
    
    manager.prepareRecording(infoDict)
    manager.startRecording()
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
      manager.pauseRecording()
      
      XCTAssertTrue(manager.isRecording)
      XCTAssertTrue(manager.isPaused)
      
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testResumeRecording() {
    let expectation = XCTestExpectation()
    let manager: RecordingManager = self.manager
    let info = Helper.recordingInfo
    let infoDict = ["encounterID": info.encounterID, "userID": info.userID]
    
    manager.prepareRecording(infoDict)
    manager.startRecording()
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
      manager.pauseRecording()
      
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
        manager.resumeRecording()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
          XCTAssertTrue(manager.isRecording)
          XCTAssertFalse(manager.isPaused)
          
          //TODO: Assert that socket is open?
          
          expectation.fulfill()
        }
      }
    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testStopRecording() {
    let expectation = XCTestExpectation()
    let manager: RecordingManager = self.manager
    let info = Helper.recordingInfo
    let infoDict = ["encounterID": info.encounterID, "userID": info.userID]
    
    manager.prepareRecording(infoDict)
    manager.startRecording()
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
      manager.stopRecording()
      
      XCTAssertFalse(manager.isRecording)
      XCTAssertFalse(manager.isPaused)
      XCTAssertNil(Defaults[.pauseTimestamp])
      XCTAssertNil(manager.currentRecordingInfo)
      
      expectation.fulfill()

    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testInterruptionBegan() {
    let expectation = XCTestExpectation()
    let manager: RecordingManager = self.manager
    let info = Helper.recordingInfo
    let infoDict = ["encounterID": info.encounterID, "userID": info.userID]
    
    manager.prepareRecording(infoDict)
    manager.startRecording()
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
      NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), userInfo: [AVAudioSessionInterruptionTypeKey:  AVAudioSession.InterruptionType.began.rawValue])
      
      XCTAssertTrue(manager.isRecording)
      XCTAssertTrue(manager.isPaused)
      XCTAssertTrue(manager.isAudioInterrupted)
      
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testInterruptionEnded() {
    let expectation = XCTestExpectation()
    let manager: RecordingManager = self.manager
    let info = Helper.recordingInfo
    let infoDict = ["encounterID": info.encounterID, "userID": info.userID]
    
    manager.prepareRecording(infoDict)
    manager.startRecording()
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
      NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), userInfo: [AVAudioSessionInterruptionTypeKey:  AVAudioSession.InterruptionType.ended.rawValue])
      
      XCTAssertTrue(manager.isRecording)
      XCTAssertFalse(manager.isPaused)
      XCTAssertFalse(manager.isAudioInterrupted)
      
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testSocketCloseShouldNotStopRecording() {
    let expectation = XCTestExpectation()
    let manager: RecordingManager = self.manager
    let info = Helper.recordingInfo
    let infoDict = ["encounterID": info.encounterID, "userID": info.userID]
    
    manager.prepareRecording(infoDict)
    manager.startRecording()

    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {      
      XCTAssertTrue(manager.isRecording, "Manager should continue recording")
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10)
  }
}
