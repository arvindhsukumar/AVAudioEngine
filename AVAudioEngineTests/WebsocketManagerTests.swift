//
//  WebsocketManagerTests.swift
//  AVAudioEngineTests
//
//  Created by arvindhsukumar on 17/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import XCTest
@testable import AVAudioEngine

class WebsocketManagerTests: XCTestCase {
  var manager: WebsocketManager!
  
  override func setUp() {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.manager = WebsocketManager(accessToken: "1234")
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testConnect() {
    let manager: WebsocketManager = self.manager
    let info = Helper.recordingInfo
    let expectation = XCTestExpectation()
    
    XCTAssertNil(manager.onConnect, "onConnect should be nil before connecting")
    
    manager.connect(info: info) { (_) in
      XCTAssertNotNil(manager.currentRecordingInfo)
      
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
        XCTAssertNil(manager.onConnect, "onConnect should be nil-ed out after connecting")
        expectation.fulfill()
      }
    }
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testCreateSocket() {
    let manager: WebsocketManager = self.manager
    
    XCTAssertNil(manager.socket)
    manager.createSocket()
    XCTAssertNotNil(manager.socket)
    XCTAssertNotNil(manager.socket?.delegate)
  }
  
  func testStop() {
    let manager: WebsocketManager = self.manager
    let info = Helper.recordingInfo
    let expectation = XCTestExpectation()
    
    manager.connect(info: info) { (_) in
    }
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
      XCTAssertNotNil(manager.currentRecordingInfo)
      XCTAssertNil(manager.onStop, "onStop should be nil before stopping")
     
      manager.stop { (_) in }
      
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
        XCTAssertNil(manager.onStop, "onStop should be nil-ed out after stopping")
        expectation.fulfill()
      }
    }
    
    wait(for: [expectation], timeout: 10)
  }
}
