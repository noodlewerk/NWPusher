//
//  NWHub.h
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>

@class NWNotification, NWPusher;

/** Allows callback on errors while pushing to and reading from server. */
@protocol NWHubDelegate <NSObject>
/** The notification failed during or after pushing. */
- (void)notification:(NWNotification *)notification didFailWithError:(NSError *)error;
@optional
- (void)notification:(NWNotification *)notification didFailWithResult:(NWError)result; // TODO: deprecated, remove from 0.6.0
@end

/** Helper on top of NWPusher that hides the details of pushing and reading. */
@interface NWHub : NSObject

/** @name Properties */

/** The pusher instance that does the actual work. */
@property (nonatomic, strong) NWPusher *pusher;

/** Assign this delegate to get notified when something fails during or after pushing. */
@property (nonatomic, weak) id<NWHubDelegate> delegate;

/** The type of notification serialization we'll be using. */
@property (nonatomic, assign) NWNotificationType type;

/** The timespan we'll hold on to a notification after pushing, allowing the server to respond. */
@property (nonatomic, assign) NSTimeInterval feedbackSpan;

/** The index incremented on every notification push, used as notification identifier. */
@property (nonatomic, assign) NSUInteger index;

/** @name Initialization */

/** Create and return a hub object with a delegate object assigned. */
- (instancetype)initWithDelegate:(id<NWHubDelegate>)delegate;

/** Create and return a hub object with a delegate and pusher object assigned. */
- (instancetype)initWithPusher:(NWPusher *)pusher delegate:(id<NWHubDelegate>)delegate;

/** Create, connect and returns an instance with delegate and identity. */
+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate identity:(NWIdentityRef)identity error:(NSError **)error;

/** Create, connect and returns an instance with delegate and identity. */
+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate PKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error;

/** @name Connecting */

/** Connect the pusher using the identity to setup the SSL connection. */
- (BOOL)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error;

/** Connect the pusher using the PKCS #12 data to setup the SSL connection. */
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error;

/** Reconnect with the server, to recover from a closed or defect connection. */
- (BOOL)reconnectWithError:(NSError **)error;

/** Close the connection, allows reconnecting. */
- (void)disconnect;

/** @name Pushing (easy) */

/** Push a JSON string payload to a device with token string. */
- (NSUInteger)pushPayload:(NSString *)payload token:(NSString *)token;

/** Push a JSON string payload to multiple devices with token strings. */
- (NSUInteger)pushPayload:(NSString *)payload tokens:(NSArray *)tokens;

/** Push multiple JSON string payloads to a device with token string. */
- (NSUInteger)pushPayloads:(NSArray *)payloads token:(NSString *)token;

/** Push multiple notifications, each representing a payload and a device token. */
- (NSUInteger)pushNotifications:(NSArray *)notifications;

/** Read the response from the server to see if any pushes have failed. */
- (NSUInteger)readFailed;

/** @name Pushing (pros) */

/** Push a notification and reconnect if anything failed. */
- (BOOL)pushNotification:(NWNotification *)notification autoReconnect:(BOOL)reconnect error:(NSError **)error;

/** Read the response from the server and reconnect if anything failed. */
- (BOOL)readFailed:(NWNotification **)notification autoReconnect:(BOOL)reconnect error:(NSError **)error;

/** Let go of old notification, after you read the failed notifications. */
- (BOOL)trimIdentifiers;

// deprecated

- (NWError)connectWithIdentity:(NWIdentityRef)identity __deprecated;
- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password __deprecated;
- (NWError)reconnect __deprecated;
- (NSUInteger)pushNotifications:(NSArray *)notifications autoReconnect:(BOOL)reconnect __deprecated;
- (NSUInteger)flushFailed __deprecated;
- (NSUInteger)fetchFailed __deprecated;
- (BOOL)fetchFailed:(BOOL *)failed autoReconnect:(BOOL)reconnect error:(NSError **)error __deprecated;

@end
