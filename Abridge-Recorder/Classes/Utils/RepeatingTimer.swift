/// RepeatingTimer mimics the API of DispatchSourceTimer but in a way that prevents
/// crashes that occur from calling resume multiple times on a timer that is
/// already resumed (noted by https://github.com/SiftScience/sift-ios/issues/52
///
/// Ref: https://gist.github.com/danielgalasko/1da90276f23ea24cb3467c33d2c05768#file-repeatingtimer-swift

class RepeatingTimer {
  let timeInterval: TimeInterval

  init(timeInterval: TimeInterval) {
    self.timeInterval = timeInterval
  }

  private lazy var timer: DispatchSourceTimer = {
    let t = DispatchSource.makeTimerSource()
    t.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)
    t.setEventHandler(handler: { [weak self] in
      guard let this = self else {
        return
      }
      
      this.eventHandler?(this.timeInterval)
    })
    return t
  }()

  var eventHandler: ((TimeInterval) -> Void)?

  private enum State {
    case suspended
    case resumed
  }

  private var state: State = .suspended

  deinit {
    timer.setEventHandler {}
    timer.cancel()
    /*
     If the timer is suspended, calling cancel without resuming
     triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
     */
    resume()
    eventHandler = nil
  }

  func resume() {
    if state == .resumed {
      return
    }
    state = .resumed
    timer.resume()
  }

  func suspend() {
    if state == .suspended {
      return
    }
    state = .suspended
    timer.suspend()
  }
}
