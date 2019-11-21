//
//  ViewController.swift
//  AVAudioEngine
//
//  Created by arvindh on 12/07/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import UIKit
import SnapKit
import AVFoundation
import Abridge_Recorder

fileprivate let kAccessToken = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjhhMzY5M2YxMzczZjgwYTI1M2NmYmUyMTVkMDJlZTMwNjhmZWJjMzYiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiQXJ2aW5kaCBTdWt1bWFyIiwiaXNzIjoiaHR0cHM6Ly9zZWN1cmV0b2tlbi5nb29nbGUuY29tL2NsaWVudC1kZXYtZTMwMWQiLCJhdWQiOiJjbGllbnQtZGV2LWUzMDFkIiwiYXV0aF90aW1lIjoxNTc0MzI5MzQ5LCJ1c2VyX2lkIjoiVTN4RGZUdUQ1ZGZHdll5M3F0U0FSVTkwVldaMiIsInN1YiI6IlUzeERmVHVENWRmR3ZZeTNxdFNBUlU5MFZXWjIiLCJpYXQiOjE1NzQzMjkzNDksImV4cCI6MTU3NDMzMjk0OSwiZW1haWwiOiJhcnZpbmRoQGFicmlkZ2UuYWkiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJhcnZpbmRoQGFicmlkZ2UuYWkiXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.kJxFoh8fOLfPggjFBJTANlCjMCWOlMbf2p-D9ZtIaIL7IbrXJPOCD-U__WtqIXAX17_OFyt9yU7BCCoWHiQ1IBfB8ed0WFJx8uBvvkG-_nGz7i1ls1u-ONVxFw0sNtzt-0_m9U-aP_AT69RsRm69yiPj4EGLwNxrD_Qr1UAtvdIF4AORV4D9jCNLdxBrq6h7vM5ru8FUnjbHtPuNfATPNhGjV6FjUvui-uiwMLw31OXpXKkuJH3J7mQZxXb-S4TQz6TzzKosYhzpNFMqsZYbrWupw9O8TlpuP5wffC9zj5UHq2jiKLybAVEWOR3Qg_RfOhAR6VCwzeDGxSkuz01Rrg"

class ViewController: UIViewController {
  let button: UIButton = {
    let button = UIButton(type: UIButton.ButtonType.system)
    button.setTitle("Record", for: UIControl.State.normal)
    return button
  }()
  
  let playButton: UIButton = {
    let button = UIButton(type: UIButton.ButtonType.system)
    button.setTitle("Play", for: UIControl.State.normal)
    return button
  }()
  
  let stopButton: UIButton = {
    let button = UIButton(type: UIButton.ButtonType.system)
    button.setTitle("Stop", for: UIControl.State.normal)
    return button
  }()
  
  let label: UILabel = {
    let label = UILabel()
    label.textAlignment = .center
    label.numberOfLines = 0
    return label
  }()
  
  var audioEngine = AVAudioEngine()
  var playNode: AVAudioPlayerNode!
  var audioFile: AVAudioFile? {
    didSet {
      if let audioFile = audioFile {
        audioLengthSamples = audioFile.length
        audioFormat = audioFile.processingFormat
        audioSampleRate = Float(audioFormat?.sampleRate ?? 44100)
        audioLengthSeconds = Float(audioLengthSamples) / audioSampleRate
      }
    }
  }
  var audioFormat: AVAudioFormat?
  var audioSampleRate: Float = 0
  var audioLengthSeconds: Float = 0
  var audioLengthSamples: AVAudioFramePosition = 0

 override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    
    AVAudioSession.sharedInstance().requestRecordPermission { (auth) in
      print(auth)
    }
    setupViews()
    setupRecordingManager()
  }

  func setupViews() {
    view.backgroundColor = UIColor.white
    
    view.addSubview(button)
    button.snp.makeConstraints { (make) in
      make.centerX.equalTo(view)
      make.centerY.equalTo(view).offset(-300)
      make.width.equalTo(200)
      make.height.equalTo(44)
    }
    
    button.addTarget(self, action: #selector(self.toggleRecording), for: UIControl.Event.touchUpInside)
    
    view.addSubview(stopButton)
    stopButton.snp.makeConstraints { (make) in
      make.centerX.equalTo(view)
      make.width.equalTo(200)
      make.height.equalTo(44)
      make.top.equalTo(button.snp.bottom).offset(10)
    }
    stopButton.addTarget(self, action: #selector(self.stopRecording), for: UIControl.Event.touchUpInside)
    
    view.addSubview(playButton)
    playButton.snp.makeConstraints { (make) in
      make.centerX.equalTo(view)
      make.width.equalTo(200)
      make.height.equalTo(44)
      make.top.equalTo(stopButton.snp.bottom).offset(10)
    }
    
    playButton.addTarget(self, action: #selector(self.playRecording), for: UIControl.Event.touchUpInside)
    
    
    
    view.addSubview(label)
    label.snp.makeConstraints { (make) in
      make.centerX.equalTo(view)
      make.left.equalTo(view).offset(10)
      make.right.equalTo(view).offset(-10)
      make.height.equalTo(150)
      make.top.equalTo(playButton.snp.bottom).offset(10)
    }

  }
  
  func setupEngine() {
    playNode = AVAudioPlayerNode()
    audioEngine.attach(playNode)
    let format = audioEngine.mainMixerNode.inputFormat(forBus: 0)
    audioEngine.connect(playNode, to: audioEngine.mainMixerNode, format: audioFormat!)
    try! audioEngine.start()

  }
  
  func setupRecordingManager() {
    AudioRecorderManager.shared
  }
  
  @objc func stopRecording() {
    AudioRecorderManager.shared.stopRecording()
  }

  @objc func toggleRecording() {
    let manager = AudioRecorderManager.shared
    if manager.isRecording {
      if button.currentTitle == "Pause" {
        manager.pauseRecording()
        button.setTitle("Record", for: UIControl.State.normal)
      }
      else {
        manager.resumeRecording()
        button.setTitle("Pause", for: UIControl.State.normal)
      }      
    }
    else {
      manager.prepareRecording(["encounterID": "1", "userID": "U3xDfTuD5dfGvYy3qtSARU90VWZ2", "token": kAccessToken])
      manager.startRecording()
      button.setTitle("Pause", for: UIControl.State.normal)
    }
  }
  
  @objc func playRecording() {
    let url = Helper.recordingURL(forEncounterID: "2")
//    audioFile = try! AVAudioFile(forReading: url)
//
//    setupEngine()
//
//    playNode.scheduleFile(audioFile!, at: nil) {
//
//    }
//    self.playNode.play()
//
//    label.text = """
//      \(audioFormat!) \n
//      \(audioLengthSeconds) \n
//      \(audioLengthSamples)
//    """
    
    let attributes = try! FileManager.default.attributesOfItem(atPath: url.path)
    let fileURL = URL(fileURLWithPath: url.path)
//    let data = try! FileManager.default.contents(atPath: url.path)
    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    present(activity, animated: true, completion: nil)
  }
}

