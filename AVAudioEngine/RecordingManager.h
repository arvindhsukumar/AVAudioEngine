//
//  RecordingManager.h
//  AVAudioEngine
//
//  Created by arvindh on 16/07/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RecordingManager : NSObject

@property (assign, nonatomic) BOOL isRecording;
@property (assign, nonatomic) BOOL isPaused;

+(instancetype)sharedInstance;
-(void)startRecording;
-(void)stopRecording;
- (void)pauseRecording;
- (void)resumeRecording;

@end

NS_ASSUME_NONNULL_END
