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

@interface RecordingManager() {
  // AVAudioEngine and AVAudioNodes
  AVAudioEngine           *_engine;
  AVAudioMixerNode        *_downMixer;
  
  // buffer for the player
  AVAudioPCMBuffer        *_playerLoopBuffer;
  
  // for the node tap
  NSURL                   *_mixerOutputFileURL;
  
  // mananging session and configuration changes
  BOOL                    _isSessionInterrupted;
  BOOL                    _isConfigChangePending;
  NSMutableData           *recordingData;
}

- (void)handleInterruption:(NSNotification *)notification;

@end

@implementation RecordingManager

@synthesize isRecording = _isRecording;

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
    [self setupSession];
    [self setupEngine];
  }
  return self;
}

-(void)setupEngine {
  _engine = [[AVAudioEngine alloc] init];
  
  _downMixer = [[AVAudioMixerNode alloc] init];
  [_engine attachNode:_downMixer];
  
  [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioEngineConfigurationChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
    
    // if we've received this notification, something has changed and the engine has been stopped
    // re-wire all the connections and reset any state that may have been lost due to nodes being
    // uninitialized when the engine was stopped
    
    _isConfigChangePending = YES;
    
    if (!_isSessionInterrupted) {
      NSLog(@"Received a %@ notification!", AVAudioEngineConfigurationChangeNotification);
      NSLog(@"Re-wiring connections");
      [self makeEngineConnections];
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

-(void)makeEngineConnections {
  AVAudioInputNode *input = [_engine inputNode];
  AVAudioFormat *inputFormat = [input outputFormatForBus:0];
  [_engine connect:input to:_downMixer format:inputFormat];

  AVAudioFormat *outputFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:44100 channels:2 interleaved:NO];

  [_engine connect:_downMixer to:[_engine mainMixerNode] format:outputFormat];
}

-(void)startEngine {
  NSError *error;
  bool success = [_engine startAndReturnError:&error];
  NSAssert(success, @"couldn't start engine, %@", [error localizedDescription]);
}

- (void)startRecording {
  if (!_engine.isRunning) {
    [self makeEngineConnections];
    [self startEngine];
  }
  
  if (!_mixerOutputFileURL) _mixerOutputFileURL = [NSURL URLWithString:[NSTemporaryDirectory() stringByAppendingString:@"mixerOutput.flac"]];
  
  AVAudioNode *mixerNode = _downMixer;
  NSDictionary *settings = [[mixerNode outputFormatForBus:0] settings];
  
  AVAudioNodeBus bus = 0;
  AVAudioFormat *format = [mixerNode outputFormatForBus:bus];
  AVAudioFormat *convertFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:16000 channels:1 interleaved:NO];
  
  recordingData = [NSMutableData data];
  
  
  [mixerNode installTapOnBus:bus bufferSize:1024 format:format block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
    AVAudioConverter *converter = [[AVAudioConverter alloc] initFromFormat:buffer.format toFormat:convertFormat];
    AVAudioPCMBuffer *newBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:convertFormat frameCapacity:buffer.frameCapacity];
    
    NSError *convertError;
    [converter convertToBuffer:newBuffer error:&convertError withInputFromBlock:^AVAudioBuffer * _Nullable(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus * _Nonnull outStatus) {
      outStatus = AVAudioConverterInputStatus_HaveData;
      return buffer;
    }];
    
    flacWriterState *outputState = FLAC__encodeSingle16bit(*newBuffer.int16ChannelData, 44100, newBuffer.frameLength);
    NSData *data = [[NSData alloc] initWithBytes:outputState->data length:outputState->pointer];
    [recordingData appendData:data];
    flacWriterStateDes(outputState);
  }];
  
  _isRecording = YES;
  
  NSLog(@"recording to file: %@", _mixerOutputFileURL.absoluteString);
}

- (void)stopRecording {
  if (_isRecording) {
    AVAudioNode *mixerNode = _downMixer;

    [mixerNode removeTapOnBus:0];
    [_engine stop];
    NSLog(@"finished recording data of length: %lu", recordingData.length);
    [[NSFileManager defaultManager] createFileAtPath:_mixerOutputFileURL.path contents:recordingData attributes:nil];
    _isRecording = NO;
  }
}

@end

