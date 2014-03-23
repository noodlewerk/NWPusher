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
- (void)notification:(NWNotification *)notification didFailWithResult:(NWError)result;
@end


@interface NWHub : NSObject

@property (nonatomic, strong) NWPusher *pusher;
@property (nonatomic, weak) id<NWHubDelegate> delegate;
@property (nonatomic, assign) NWNotificationType type;
@property (nonatomic, assign) NSTimeInterval feedbackSpan;

- (instancetype)initWithDelegate:(id<NWHubDelegate>)delegate;
- (instancetype)initWithPusher:(NWPusher *)pusher delegate:(id<NWHubDelegate>)delegate;

- (NWError)connectWithIdentity:(NWIdentityRef)identity;
- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password;
- (NWError)reconnect;
- (void)disconnect;

- (NSUInteger)pushPayload:(NSString *)payload token:(NSString *)token;
- (NSUInteger)pushPayload:(NSString *)payload tokens:(NSArray *)tokens;
- (NSUInteger)pushPayloads:(NSArray *)payloads token:(NSString *)token;
- (NSUInteger)pushNotifications:(NSArray *)notifications autoReconnect:(BOOL)reconnect;
- (NSUInteger)flushFailed;

// deprecated
#if !TARGET_OS_IPHONE
- (NWError)connectWithCertificateRef:(SecCertificateRef)certificate __attribute__((deprecated));
#endif
- (NWError)connectWithIdentityRef:(SecIdentityRef)identity __attribute__((deprecated));

@end
