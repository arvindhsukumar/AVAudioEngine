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

+(instancetype)sharedInstance;
-(void)startRecording;
-(void)stopRecording;

@end

NS_ASSUME_NONNULL_END
