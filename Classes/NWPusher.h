//
//  NWPusher.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>

@class NWNotification, NWSSLConnection;

/** Serializes notification objects and pushes them to the APNs.
 
 This is the heart of the framework. As the (inconvenient) name suggest, it's also one of the first classes that was added to the framework. This class provides a straightforward interface to the APNs, including connecting, pushing to and reading from the server.
 
 Connecting is done based on an identity or PKCS #12 data. The identity is an instance of `SecIdentityRef` and contains a certificate and private key. The PKCS #12 data can be deserialized into such an identity. One can reconnect or disconnect at any time, and should if the connection has been dropped by the server. The latter can happen quite easily, for example when there is something wrong with the device token or payload of the notification.
 
 Notifications are pushed one at a time. It is serialized and sent over the wire. If the server then concludes there is something wrong with that notification, it will write back error data. If you send out multiple notifications in a row, these errors might not match up. Therefore every error contains the identifier of the erroneous notification.
 
 Make sure to read this error data from the server, so you can lookup the notification that caused it and prevent the issue in the future. As mentioned earlier, the server easily drops the connection if there is something out of the ordinary. NB: if you read right after pushing, it is very unlikely that data about that push already got back from the server.
 
 Make sure to read Apple's documentation on *Apple Push Notification Service* and *Provider Communication*.
 */
@interface NWPusher : NSObject

/** @name Properties */

/** The SSL connection through which all notifications are pushed. */
@property (nonatomic, strong) NWSSLConnection *connection;

/** @name Initialization */

/** Creates, connects and returns a pusher object based on the provided identity. */
+ (instancetype)connectWithIdentity:(NWIdentityRef)identity environment:(NWEnvironment)environment error:(NSError **)error;

/** Creates, connects and returns a pusher object based on the PKCS #12 data. */
+ (instancetype)connectWithPKCS12Data:(NSData *)data password:(NSString *)password environment:(NWEnvironment)environment error:(NSError **)error;

/** @name Connecting */

/** Connect with the APNs using the identity. */
- (BOOL)connectWithIdentity:(NWIdentityRef)identity environment:(NWEnvironment)environment error:(NSError **)error;

/** Connect with the APNs using the identity from PKCS #12 data. */
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password environment:(NWEnvironment)environment error:(NSError **)error;

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

+ (instancetype)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error __deprecated;
+ (instancetype)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error __deprecated;
- (BOOL)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error __deprecated;
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error __deprecated;

@end
