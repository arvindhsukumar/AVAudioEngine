//
//  RecordingManager.m
//  AVAudioEngine
//
//  Created by arvindh on 16/07/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

#import "RecordingManager.h"
#import <AVFoundation/AVFoundation.h>
#import <FLACiOS/all.h>
#import "encode_single_16bit.h"
#import "WebsocketManager.h"
#import "AVAudioEngine-Swift.h"

NSString const *kAccessToken = @"eyJhbGciOiJSUzI1NiIsImtpZCI6IjcyODRlYTZiNGZlZDBmZDc1MzE4NTg2NDZmZDYzNjE1ZGQ3YTIyZjUiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiQXJ2aW5kaCBTdWt1bWFyIiwiaXNzIjoiaHR0cHM6Ly9zZWN1cmV0b2tlbi5nb29nbGUuY29tL2NsaWVudC1kZXYtZTMwMWQiLCJhdWQiOiJjbGllbnQtZGV2LWUzMDFkIiwiYXV0aF90aW1lIjoxNTY1MTc3NDE0LCJ1c2VyX2lkIjoiVTN4RGZUdUQ1ZGZHdll5M3F0U0FSVTkwVldaMiIsInN1YiI6IlUzeERmVHVENWRmR3ZZeTNxdFNBUlU5MFZXWjIiLCJpYXQiOjE1NjUxNzc0MTQsImV4cCI6MTU2NTE4MTAxNCwiZW1haWwiOiJhcnZpbmRoQGFicmlkZ2UuYWkiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJhcnZpbmRoQGFicmlkZ2UuYWkiXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.nXq2myI4FsR7I6PMjbsferc7XoMZl1FYMQBQfKsmSaYIlEZhaQfvbMombgQRD9daBPFQ_uTwfC7WcSq08ULl6MrYDEuaJnYO9-AUV60yiTjFg5HIP5hFNHKuf_wYtvcpVnlKKory4z6-9uUKM12FXqo3o5SpgtI3mDgYczpwYvRwOVNJ2JWoZVLckj-fYSf8xHbL8wpnNs2E7snBCQeqmvI5MHYZoBawZTRy3tPqlIVxbAETnXIYdZIF03H-HPGncrnwPCVMYY1Pw9Q_EyvOA3nLXiceCrkdMWOrLtwPO8Mu-NfgKWA7lkUL0SW2Q0mn5ecKsHORjDzgtI8hOgcheA";

@interface RecordingManager() {
  // AVAudioEngine and AVAudioNodes
  Recorder                *_recorder;
  // buffer for the player
  AVAudioPCMBuffer        *_playerLoopBuffer;
  
  // for the node tap
  NSURL                   *_mixerOutputFileURL;
  
  // mananging session and configuration changes
  BOOL                    _isSessionInterrupted;
  BOOL                    _isConfigChangePending;
  NSMutableData           *recordingData;
  
  WebsocketManager *websocketManager;
}

- (void)handleInterruption:(NSNotification *)notification;

@end

@implementation RecordingManager

+(instancetype)sharedInstance {
  static RecordingManager *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

-(instancetype)init {
  if (self = [super init]) {
    // write your code here
    NSLog(@"%@", @"init shared instance");
    [self setupWebsocket];
    [self setupSession];
    [self setupEngine];
  }
  return self;
}

- (bool)isRecording {
  return [_recorder isRecording];
}

-(void)setupWebsocket {
  websocketManager = [[WebsocketManager alloc] initWithAccessToken: kAccessToken];
  [websocketManager connect];
}

-(void)setupEngine {
  _recorder = [[Recorder alloc] init];
  
  [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioEngineConfigurationChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
    
    // if we've received this notification, something has changed and the engine has been stopped
    // re-wire all the connections and reset any state that may have been lost due to nodes being
    // uninitialized when the engine was stopped
    
    _isConfigChangePending = YES;
    
    if (!_isSessionInterrupted) {
      NSLog(@"Received a %@ notification!", AVAudioEngineConfigurationChangeNotification);
      NSLog(@"Re-wiring connections");
      [_recorder makeEngineConnections];
    } else {
      NSLog(@"Session is interrupted, deferring changes");
    }
  }];
}

-(void)setupSession {
  AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
  NSError *error;
  
  bool success = [sessionInstance setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
  if (!success) NSLog(@"Error setting AVAudioSession category! %@\n", [error localizedDescription]);
  
  double hwSampleRate = 44100.0;
  success = [sessionInstance setPreferredSampleRate:hwSampleRate error:&error];
  if (!success) NSLog(@"Error setting preferred sample rate! %@\n", [error localizedDescription]);
  
  NSTimeInterval ioBufferDuration = 0.0029;
  success = [sessionInstance setPreferredIOBufferDuration:ioBufferDuration error:&error];
  if (!success) NSLog(@"Error setting preferred io buffer duration! %@\n", [error localizedDescription]);
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleInterruption:)
                                               name:AVAudioSessionInterruptionNotification
                                             object:sessionInstance];
  
  success = [sessionInstance setActive:YES error:&error];
  if (!success) NSLog(@"Error setting session active! %@\n", [error localizedDescription]);
}

- (void)handleInterruption:(NSNotification *)notification {
  
}


- (void)startRecording {
  [websocketManager start];
  [_recorder startRecording:^(NSData * _Nonnull data) {
    NSLog(@"%lu", (unsigned long)data.length);
    [self->websocketManager sendData:data];
  }];  
}

- (void)stopRecording {
  [_recorder stopRecording];
  [websocketManager sendMessage:@"{\"type\": \"stop\"}"];
}

@end

