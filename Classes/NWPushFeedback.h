//
//  NWPushFeedback.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>

@class NWSSLConnection;

/** Reads tokens and dates from the APNs feedback service.
 
 The feedback service is a separate server that provides a list of all device tokens that it tried to deliver a notification to, but was unable to. This usually indicates that this device no longer has the app installed. This way, the feedback service provides reliable way of finding out who uninstalled the app, which can be fed back into your database.
 
 Apple recommends reading from the service once a day. After a device token has been read, it will not be returned again until the next failed delivery. In practice: connect once a day, read all device tokens, and update your own database accordingly.
 
 Read more in Apple's documentation under *The Feedback Service*.
 */
@interface NWPushFeedback : NSObject

/** @name Properties */

@property (nonatomic, strong) NWSSLConnection *connection;

/** @name Initialization */

/** Setup connection with feedback service based on identity. */
+ (instancetype)connectWithIdentity:(NWIdentityRef)identity environment:(NWEnvironment)environment error:(NSError **)error;

/** Setup connection with feedback service based on PKCS #12 data. */
+ (instancetype)connectWithPKCS12Data:(NSData *)data password:(NSString *)password environment:(NWEnvironment)environment error:(NSError **)error;

/** @name Connecting */

/** Connect with feedback service based on identity. */
- (BOOL)connectWithIdentity:(NWIdentityRef)identity environment:(NWEnvironment)environment error:(NSError **)error;

/** Connect with feedback service based on PKCS #12 data. */
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password environment:(NWEnvironment)environment error:(NSError **)error;

/** Disconnect from feedback service. The server will automatically drop the connection after all feedback data has been read. */
- (void)disconnect;

/** @name Reading */

/** Read a single token-date pair, where token is data. */
- (BOOL)readTokenData:(NSData **)token date:(NSDate **)date error:(NSError **)error;

/** Read a single token-date pair, where token is hex string. */
- (BOOL)readToken:(NSString **)token date:(NSDate **)date error:(NSError **)error;

/** Read all (or max) token-date pairs, where token is hex string. */
- (NSArray *)readTokenDatePairsWithMax:(NSUInteger)max error:(NSError **)error;

// deprecated

+ (instancetype)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error __deprecated;
+ (instancetype)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error __deprecated;
- (BOOL)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error __deprecated;
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error __deprecated;

@end
