//
//  NWHub.h
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import "NWPusher.h"
#import <Foundation/Foundation.h>

@class NWNotification, NWPusher;
@protocol NWHubDelegate;


@interface NWHub : NSObject

@property (nonatomic, strong) NWPusher *pusher;
@property (nonatomic, weak) id<NWHubDelegate> delegate;
@property (nonatomic, assign) NWNotificationType type;
@property (nonatomic, assign) NSTimeInterval feedbackSpan;

- (id)initWithPusher:(NWPusher *)pusher delegate:(id<NWHubDelegate>)delegate;
- (NSUInteger)pushPayload:(NSString *)payload token:(NSString *)token;
- (NSUInteger)pushPayload:(NSString *)payload tokens:(NSArray *)tokens;
- (NSUInteger)pushPayloads:(NSArray *)payloads token:(NSString *)token;
- (NSUInteger)pushNotifications:(NSArray *)notifications;
- (NSUInteger)flushFailed;
- (NWPusherResult)reconnect;
- (void)disconnect;

@end


@protocol NWHubDelegate <NSObject>

- (void)notification:(NWNotification *)notification didFailWithResult:(NWPusherResult)result;

@end