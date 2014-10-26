//
//  NWPusher.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>

@class NWNotification, NWSSLConnection;

/** Serializes notification objects and pushes them to the APNS. */
@interface NWPusher : NSObject

/** @name Properties */

/** The SSL connection though which all notifications are pushed. */
@property (nonatomic, strong) NWSSLConnection *connection;

/** @name Initialization */

/** Creates, connects and returns a pusher object based on the provided identity. */
+ (instancetype)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error;

/** Creates, connects and returns a pusher object based on the PKCS #12 data. */
+ (instancetype)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error;

/** @name Connecting */

/** Connect with the APNS server using the identity. */
- (BOOL)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error;

/** Connect with the APNS server using the identity from PKCS #12 data. */
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error;

/** Reconnect using the same identity, disconnects if necessary. */
- (BOOL)reconnectWithError:(NSError **)error;

/** Disconnect from the server, allows reconnect. */
- (void)disconnect;

/** @name Pushing */

/** Push a JSON string payload to a device with token string, assign identifier. */
- (BOOL)pushPayload:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier error:(NSError **)error;

/** Push a notification using push type for serialization. */
- (BOOL)pushNotification:(NWNotification *)notification type:(NWNotificationType)type error:(NSError **)error;

/** @name Reading */

/** Read back from the server the notification identifiers of failed pushes. */
- (BOOL)readFailedIdentifier:(NSUInteger *)identifier apnError:(NSError **)apnError error:(NSError **)error;

/** Read back multiple notification identifiers of, up to max, failed pushes. */
- (NSArray *)readFailedIdentifierErrorPairsWithMax:(NSUInteger)max error:(NSError **)error;

// deprecated

- (NWError)connectWithIdentity:(NWIdentityRef)identity __deprecated;
- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password __deprecated;
- (NWError)reconnect __deprecated;
- (NWError)pushPayload:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier __deprecated;
- (NWError)pushNotification:(NWNotification *)notification type:(NWNotificationType)type __deprecated;
- (NWError)fetchFailedIdentifier:(NSUInteger *)identifier apnError:(NWError *)apnError __deprecated;
- (BOOL)fetchFailedIdentifier:(NSUInteger *)identifier apnError:(NSError **)apnError error:(NSError **)error __deprecated;
- (NSArray *)fetchFailedIdentifierErrorPairsWithMax:(NSUInteger)max error:(NSError **)error __deprecated;

@end
