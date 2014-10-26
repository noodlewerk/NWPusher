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
- (void)notification:(NWNotification *)notification didFailWithResult:(NWError)result __deprecated; // TODO: deprecated, remove from 0.6.0
@end


@interface NWHub : NSObject

@property (nonatomic, strong) NWPusher *pusher;
@property (nonatomic, weak) id<NWHubDelegate> delegate;
@property (nonatomic, assign) NWNotificationType type;
@property (nonatomic, assign) NSTimeInterval feedbackSpan;

@property (nonatomic, assign) NSUInteger index;

- (instancetype)initWithDelegate:(id<NWHubDelegate>)delegate;
- (instancetype)initWithPusher:(NWPusher *)pusher delegate:(id<NWHubDelegate>)delegate;

- (BOOL)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error;
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error;
- (BOOL)reconnectWithError:(NSError **)error;
- (void)disconnect;

+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate identity:(NWIdentityRef)identity error:(NSError **)error;
+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate PKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error;

- (NSUInteger)pushPayload:(NSString *)payload token:(NSString *)token;
- (NSUInteger)pushPayload:(NSString *)payload tokens:(NSArray *)tokens;
- (NSUInteger)pushPayloads:(NSArray *)payloads token:(NSString *)token;
- (NSUInteger)pushNotifications:(NSArray *)notifications;
- (NSUInteger)fetchFailed;

- (BOOL)pushNotification:(NWNotification *)notification autoReconnect:(BOOL)reconnect error:(NSError **)error;
- (BOOL)fetchFailed:(BOOL *)failed autoReconnect:(BOOL)reconnect error:(NSError **)error;
- (BOOL)trimIdentifiers;

// deprecated

- (NWError)connectWithIdentity:(NWIdentityRef)identity __deprecated;
- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password __deprecated;
- (NWError)reconnect __deprecated;
- (NSUInteger)pushNotifications:(NSArray *)notifications autoReconnect:(BOOL)reconnect __deprecated;
- (NSUInteger)flushFailed __deprecated;

@end
