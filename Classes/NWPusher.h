//
//  NWPusher.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>

@class NWNotification, NWSSLConnection;


@interface NWPusher : NSObject

@property (nonatomic, readonly) NWSSLConnection *connection;

- (BOOL)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error;
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error;
- (BOOL)reconnectWithError:(NSError **)error;
- (void)disconnect;

- (BOOL)pushPayload:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier error:(NSError **)error;
- (BOOL)pushNotification:(NWNotification *)notification type:(NWNotificationType)type error:(NSError **)error;
- (BOOL)fetchFailedIdentifier:(NSUInteger *)identifier apnError:(NSError **)apnError error:(NSError **)error;

// deprecated

- (NWError)connectWithIdentity:(NWIdentityRef)identity __deprecated;
- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password __deprecated;
- (NWError)reconnect __deprecated;
- (NWError)pushPayload:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier __deprecated;
- (NWError)pushNotification:(NWNotification *)notification type:(NWNotificationType)type __deprecated;
- (NWError)fetchFailedIdentifier:(NSUInteger *)identifier apnError:(NWError *)apnError __deprecated;

@end
