//
//  RecordingManagerBridge.m
//  AVAudioEngine
//
//  Created by arvindhsukumar on 23/10/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(AudioRecorderManager, RCTEventEmitter)

RCT_EXTERN_METHOD(prepareRecording:(NSDictionary *)info)
RCT_EXTERN_METHOD(startRecording)
RCT_EXTERN_METHOD(stopRecording)
RCT_EXTERN_METHOD(pauseRecording)
RCT_EXTERN_METHOD(resumeRecording)

@end
