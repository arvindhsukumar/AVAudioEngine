//
//  WebsocketManager.h
//  AVAudioEngine
//
//  Created by arvindh on 25/07/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SocketRocket/SocketRocket.h>

NS_ASSUME_NONNULL_BEGIN

@interface WebsocketManager : NSObject<SRWebSocketDelegate>

@property (strong, nonatomic) SRWebSocket *socket;

-(instancetype)initWithAccessToken:(NSString*)accessToken;
-(void)connect;
-(void)start;
-(void)sendData:(NSData*)data;
-(void)sendMessage:(NSString*)message;

@end

NS_ASSUME_NONNULL_END
