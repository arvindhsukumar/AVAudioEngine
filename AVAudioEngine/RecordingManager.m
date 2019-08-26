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

NSString const *kAccessToken = @"eyJhbGciOiJSUzI1NiIsImtpZCI6IjI2OGNhNTBjZTY0YjQxYWIzNGZhMDM1NzIwMmQ5ZTk0ZTcyYmQ2ZWMiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiQXJ2aW5kaCBTdWt1bWFyIiwiaXNzIjoiaHR0cHM6Ly9zZWN1cmV0b2tlbi5nb29nbGUuY29tL2NsaWVudC1kZXYtZTMwMWQiLCJhdWQiOiJjbGllbnQtZGV2LWUzMDFkIiwiYXV0aF90aW1lIjoxNTY2NDc2NjYzLCJ1c2VyX2lkIjoiVTN4RGZUdUQ1ZGZHdll5M3F0U0FSVTkwVldaMiIsInN1YiI6IlUzeERmVHVENWRmR3ZZeTNxdFNBUlU5MFZXWjIiLCJpYXQiOjE1NjY0NzY2NjMsImV4cCI6MTU2NjQ4MDI2MywiZW1haWwiOiJhcnZpbmRoQGFicmlkZ2UuYWkiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJhcnZpbmRoQGFicmlkZ2UuYWkiXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.QYo1EeOQ9Eidw4El2DmC5Vx0gZFByfrRgQBEmTXDDCabTxaoOHZTsFF8zr3-IWzkhx3lOVoT0id6iaGlqiPjOl_Frv2AP37lFlxW_rl5K30uQAH6RKGOTMY21LEqTHpDTVwZYMRes8MlhcQ1tOdTNs-AoYMedYqBuS4XxcpeTC52ERngyY5YYAxYKIrdCWsVx3fbQow4swUyYI2Nk4kJu6vAzYxzw-BGqozKzjMKQDBNVzkoA1wJfNUPZS32YapCHQHNI9e0-Ph650SAsRkNM9qsfIEN17O4PoSb5xgOy_TtnuGiGZQHwenxX8dwVCH-OYbUXNVk44uLd92gsicRnQ";

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

- (bool)isPaused {
  return [_recorder isPaused];
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
    [self->websocketManager sendData:data];
  }];  
}

- (void)stopRecording {
  [_recorder stopRecording];
  [websocketManager sendMessage:@"{\"type\": \"stop\"}"];
}

- (void)pauseRecording {
  [_recorder pauseRecording];
}

- (void)resumeRecording {
  [_recorder resumeRecording];
}
@end

