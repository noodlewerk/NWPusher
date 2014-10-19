//
//  NWHub.h
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>

@class NWNotification, NWPusher;


@protocol NWHubDelegate <NSObject>
- (void)notification:(NWNotification *)notification didFailWithError:(NSError *)error;
@optional
- (void)notification:(NWNotification *)notification didFailWithResult:(NWError)result; // TODO: deprecated, remove from 0.6.0
@end


@interface NWHub : NSObject

@property (nonatomic, strong) NWPusher *pusher;
@property (nonatomic, weak) id<NWHubDelegate> delegate;
@property (nonatomic, assign) NWNotificationType type;
@property (nonatomic, assign) NSTimeInterval feedbackSpan;

- (instancetype)initWithDelegate:(id<NWHubDelegate>)delegate;
- (instancetype)initWithPusher:(NWPusher *)pusher delegate:(id<NWHubDelegate>)delegate;

- (BOOL)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error;
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error;
- (BOOL)reconnectWithError:(NSError **)error;
- (void)disconnect;

- (NSUInteger)pushPayload:(NSString *)payload token:(NSString *)token;
- (NSUInteger)pushPayload:(NSString *)payload tokens:(NSArray *)tokens;
- (NSUInteger)pushPayloads:(NSArray *)payloads token:(NSString *)token;
- (NSUInteger)pushNotifications:(NSArray *)notifications autoReconnect:(BOOL)reconnect;
- (NSUInteger)flushFailed;

// deprecated

- (NWError)connectWithIdentity:(NWIdentityRef)identity __deprecated;
- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password __deprecated;
- (NWError)reconnect __deprecated;

@end
