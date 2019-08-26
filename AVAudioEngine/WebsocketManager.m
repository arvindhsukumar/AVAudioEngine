//
//  WebsocketManager.m
//  AVAudioEngine
//
//  Created by arvindh on 25/07/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebsocketManager.h"
#import <SocketRocket/SocketRocket.h>

@interface WebsocketManager() {
  NSString* _accessToken;
}
@end
NSString const *kIPAddress = @"192.168.9.125";

@implementation WebsocketManager

@synthesize socket = _socket;

-(instancetype)initWithAccessToken:(NSString *)accessToken {
  if (self = [super init]) {
    _accessToken = accessToken;    
  }
  return self;
}

- (void)connect {
  NSURLSession *session = [NSURLSession sharedSession];
  NSString *urlString = [NSString stringWithFormat:@"%@:8080/streaming", kIPAddress];
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", urlString]]];
  [request setValue:[NSString stringWithFormat:@"Bearer %@", _accessToken] forHTTPHeaderField:@"Authorization"];
  
  NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    if ([error isEqual:[NSNull null]]) {
      NSLog(@"error: %@", error.localizedDescription);
    } else {
      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
      NSLog(@"no error %li", (long)httpResponse.statusCode);
      
      [self createSocket];
    }
  }];
  
  [task resume];
}

-(void)createSocket {
  NSString *urlString = [NSString stringWithFormat:@"%@:8080/streaming", kIPAddress];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"ws://%@", urlString]]];
  [request setValue:[NSString stringWithFormat:@"Bearer %@", _accessToken] forHTTPHeaderField:@"Authorization"];

  _socket = [[SRWebSocket alloc] initWithURLRequest:request protocols:@[@"chat",@"superchat"] allowsUntrustedSSLCertificates:YES];
  
  _socket.delegate = self;
  
  [_socket open];
}

- (void)sendData:(NSData *)data {
  [_socket send:data];
}

- (void)sendMessage:(NSString*)message {
  [_socket send:message];
}

- (void)start {
  [_socket send:@"{\"type\": \"start\",\"encounter_id\": \"some_id\",\"user_id\": \"uid\",\"recording_number\": 0}"];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
  NSLog(@"socket opened");
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
  NSLog(@"socket failed with error: %@", error.localizedDescription);
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
  NSLog(@"socket closed with reason: %@, code: %li, wasClean: %d", reason, code, wasClean);
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
  NSLog(@"socket received pong");
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
  NSLog(@"socket received message: %@", message);
}

@end
