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

- (NWError)connectWithIdentity:(NWIdentityRef)identity;
- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password;
- (NWError)reconnect;
- (void)disconnect;

- (NWError)pushPayload:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier;
- (NWError)pushNotification:(NWNotification *)notification type:(NWNotificationType)type;
- (NWError)fetchFailedIdentifier:(NSUInteger *)identifier apnError:(NWError *)apnError;

@end
