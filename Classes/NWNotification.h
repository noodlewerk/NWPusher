//
//  NWNotification.h
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>

/** A single push message, containing the receiver device token, the payload, and delivery attributes. */
@interface NWNotification : NSObject

/** @name Properties */

/** String representation of serialized JSON. */
@property (nonatomic, strong) NSString *payload;

/** UTF-8 data representation of serialized JSON. */
@property (nonatomic, strong) NSData *payloadData;

/** Hex string representation of the device token. */
@property (nonatomic, strong) NSString *token;

/** Data representation of the device token. */
@property (nonatomic, strong) NSData *tokenData;

/** Identifier used for correlating server response on error. */
@property (nonatomic, assign) NSUInteger identifier;

/** The expiration date after which the server will not attempt to deliver. */
@property (nonatomic, strong) NSDate *expiration;

/** Epoch seconds representation of expiration date. */
@property (nonatomic, assign) NSUInteger expirationStamp;

/** Notification priority used by server for delivery optimization. */
@property (nonatomic, assign) NSUInteger priority;

/** Indicates whether the expiration date should be serialized. */
@property (nonatomic, assign) BOOL addExpiration;

/** @name Initialization */

/** Create and returns a notification object based on given attribute objects. */
- (instancetype)initWithPayload:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier expiration:(NSDate *)date priority:(NSUInteger)priority;

/** Create and returns a notification object based on given raw attributes. */
- (instancetype)initWithPayloadData:(NSData *)payload tokenData:(NSData *)token identifier:(NSUInteger)identifier expirationStamp:(NSUInteger)expirationStamp addExpiration:(BOOL)addExpiration priority:(NSUInteger)priority;

/** @name Serialization */

/** Serialize this notification using provided format. */
- (NSData *)dataWithType:(NWNotificationType)type;

/** @name Helpers */

/** Converts a hex string into binary data. */
+ (NSData *)dataFromHex:(NSString *)hex;

/** Converts binary data into a hex string. */
+ (NSString *)hexFromData:(NSData *)data;

@end
