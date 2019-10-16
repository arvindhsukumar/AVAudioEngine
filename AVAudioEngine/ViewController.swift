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
      manager.startRecording()
      button.setTitle("Pause", for: UIControl.State.normal)
    }
  }
  
  @objc func playRecording() {
    let url = URL(string: NSTemporaryDirectory().appending("mixerOutput.caf"))!
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
    let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    present(activity, animated: true, completion: nil)
  }
}

