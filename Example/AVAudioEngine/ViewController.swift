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

fileprivate let kAccessToken = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjhhMzY5M2YxMzczZjgwYTI1M2NmYmUyMTVkMDJlZTMwNjhmZWJjMzYiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiQXJ2aW5kaCBTdWt1bWFyIiwiaXNzIjoiaHR0cHM6Ly9zZWN1cmV0b2tlbi5nb29nbGUuY29tL2NsaWVudC1kZXYtZTMwMWQiLCJhdWQiOiJjbGllbnQtZGV2LWUzMDFkIiwiYXV0aF90aW1lIjoxNTc0MzI1OTU5LCJ1c2VyX2lkIjoiVTN4RGZUdUQ1ZGZHdll5M3F0U0FSVTkwVldaMiIsInN1YiI6IlUzeERmVHVENWRmR3ZZeTNxdFNBUlU5MFZXWjIiLCJpYXQiOjE1NzQzMjU5NTksImV4cCI6MTU3NDMyOTU1OSwiZW1haWwiOiJhcnZpbmRoQGFicmlkZ2UuYWkiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJhcnZpbmRoQGFicmlkZ2UuYWkiXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.QrQ0IV6AxOLZDacmbzmXvwj6G26HmCnCZ2WwaUY0DdXVgqaMWNESg-cbv3dob4I2klIKrmAhrJ5pWNiF7GpVFkbpDt4VCUMwT39k2xe3Aqs8ml5qnTepLi-SzjsVq9tVt3f7wWBcdHM6E596MxU7ElSDrMkDeVbmfnr6RUXLpJk_c4MdPV2nx79Oj_QYKg3EYvQIuk0OW94DdGNjKus1Qwr5fTsFMPNzO0hHMfeV1a61mzn4xHVYab4fA51Y3eHP16VBXGtx43Cn6rcg2RTe6XheFvIt8JcCglYbHxnfwS8U727QF_h_8WiV4pr0pLmdkoTsgWoEwkbWkP2c_Tphgg"

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
    RecordingManager.shared
  }
  
  @objc func stopRecording() {
    RecordingManager.shared.stopRecording()
  }

  @objc func toggleRecording() {
    let manager = RecordingManager.shared
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

