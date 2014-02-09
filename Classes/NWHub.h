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

- (id)initWithDelegate:(id<NWHubDelegate>)delegate;
- (id)initWithPusher:(NWPusher *)pusher delegate:(id<NWHubDelegate>)delegate;

#if !TARGET_OS_IPHONE
- (NWPusherResult)connectWithCertificateRef:(SecCertificateRef)certificate;
#endif
- (NWPusherResult)connectWithIdentityRef:(SecIdentityRef)identity;
- (NWPusherResult)connectWithPKCS12Data:(NSData *)data password:(NSString *)password;
- (NWPusherResult)reconnect;
- (void)disconnect;

- (NSUInteger)pushPayload:(NSString *)payload token:(NSString *)token;
- (NSUInteger)pushPayload:(NSString *)payload tokens:(NSArray *)tokens;
- (NSUInteger)pushPayloads:(NSArray *)payloads token:(NSString *)token;
- (NSUInteger)pushNotifications:(NSArray *)notifications autoReconnect:(BOOL)reconnect;
- (NSUInteger)flushFailed;

@end


@protocol NWHubDelegate <NSObject>

- (void)notification:(NWNotification *)notification didFailWithResult:(NWPusherResult)result;

@end