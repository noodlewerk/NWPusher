//
//  NWHub.h
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>

@class NWNotification, NWPusher;

/** Allows callback on errors while pushing to and reading from server. 
 
 Check out `NWHub` for more details.
 */
@protocol NWHubDelegate <NSObject>
/** The notification failed during or after pushing. */
- (void)notification:(NWNotification *)notification didFailWithError:(NSError *)error;
@end

/** Helper on top of `NWPusher` that hides the details of pushing and reading.
 
 This class provides a more convenient way of pushing notifications to the APNs. It deals with the trouble of assigning a unique identifier to every notification and the handling of error responses from the server. It hides the latency that comes with transmitting the pushes, allowing you to simply push your notifications and getting notified of errors through the delegate. If this feels over-abstracted, then definitely check out the `NWPusher` class, which will give you full control.
 
 There are two set of methods for pushing notifications: the easy and the pros. The former will just do the pushing and reconnect if the connection breaks. This is your low-worry solution, provided that you call `readFailed` every so often (seconds) to handle error data from the server. The latter will give you a little more control and a little more responsibility.
 */
@interface NWHub : NSObject

/** @name Properties */

/** The pusher instance that does the actual work. */
@property (nonatomic, strong) NWPusher *pusher;

/** Assign a delegate to get notified when something fails during or after pushing. */
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
+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate identity:(NWIdentityRef)identity environment:(NWEnvironment)environment error:(NSError **)error;

/** Create, connect and returns an instance with delegate and identity. */
+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate PKCS12Data:(NSData *)data password:(NSString *)password environment:(NWEnvironment)environment error:(NSError **)error;

/** @name Connecting */

/** Connect the pusher using the identity to setup the SSL connection. */
- (BOOL)connectWithIdentity:(NWIdentityRef)identity environment:(NWEnvironment)environment error:(NSError **)error;

/** Connect the pusher using the PKCS #12 data to setup the SSL connection. */
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password environment:(NWEnvironment)environment error:(NSError **)error;

/** Reconnect with the server, to recover from a closed or defect connection. */
- (BOOL)reconnectWithError:(NSError **)error;

/** Close the connection, allows reconnecting. */
- (void)disconnect;

/** @name Pushing (easy) */

/** Push a JSON string payload to a device with token string.
 @see pushNotifications:
 */
- (NSUInteger)pushPayload:(NSString *)payload token:(NSString *)token;

/** Push a JSON string payload to multiple devices with token strings.
 @see pushNotifications:
 */
- (NSUInteger)pushPayload:(NSString *)payload tokens:(NSArray *)tokens;

/** Push multiple JSON string payloads to a device with token string.
 @see pushNotifications:
 */
- (NSUInteger)pushPayloads:(NSArray *)payloads token:(NSString *)token;

/** Push multiple notifications, each representing a payload and a device token.
 
 This will assign each notification a unique identifier if none was set yet. If pushing fails it will reconnect. This method can be used rather carelessly; any thing goes. However, this also means that a failed notification might break the connection temporarily, losing a notification here or there. If you are sending bulk and don't care too much about this, then you'll be fine. If not, consider using `pushNotification:autoReconnect:error:`.
 
 Make sure to call `readFailed` on a regular basis to allow server error responses to be handled and the delegate to be called.
 
 Returns the number of notifications that failed, preferably zero.
 
 @see readFailed
 */
- (NSUInteger)pushNotifications:(NSArray *)notifications;

/** Read the response from the server to see if any pushes have failed.
 
 Due to transmission latency it usually takes a couple of milliseconds for the server to respond to errors. This methods reads the server response and handles the errors. Make sure to call this regularly to catch up on malformed notifications.
 
 @see pushNotifications:
 */
- (NSUInteger)readFailed;

/** @name Pushing (pros) */

/** Push a notification and reconnect if anything failed. 
 
 This will assign the notification a unique (incremental) identifier and feed it to the internal pusher. If this succeeds, the notification is stored for later lookup by `readFailed:autoReconnect:error:`. If it fails, the delegate will be invoked and it will reconnect if set to auto-reconnect.
 
 @see readFailed:autoReconnect:error:
 */
- (BOOL)pushNotification:(NWNotification *)notification autoReconnect:(BOOL)reconnect error:(NSError **)error;

/** Read the response from the server and reconnect if anything failed.
 
 If the APNs finds something wrong with a notification, it will write back the identifier and error code. As this involves transmission to and from the server, it takes just a little while to get this failure info. This method should therefore be invoked a little (say a second) after pushing to see if anything was wrong. On a slow connection this might take longer than the interval between push messages, in which case the reported notification was *not* the last one sent.
 
 From the server we only get the notification identifier and the error message. This method translates this back into the original notification by keeping track of all notifications sent in the past 30 seconds. If somehow the original notification cannot be found, it will assign `NSNull`.
 
 Usually, when a notification fails, the server will drop the connection. To prevent this from causing any more problems, the connection can be reestablished by setting it to reconnect automatically.
 
 @see trimIdentifiers
 @see feedbackSpan
 */
- (BOOL)readFailed:(NWNotification **)notification autoReconnect:(BOOL)reconnect error:(NSError **)error;

/** Let go of old notification, after you read the failed notifications.
 
 This class keeps track of all notifications sent so we can look them up later based on their identifier. This allows it to translate identifiers back into the original notification. To limit the amount of memory all older notifications should be trimmed from this lookup, which is done by this method. This is done based on the `feedbackSpan`, which defaults to 30 seconds.
 
 Be careful not to call this function without first reading all failed notifications, using `readFailed:autoReconnect:error:`.
 
 @see readFailed:autoReconnect:error:
 @see feedbackSpan
 */
- (BOOL)trimIdentifiers;

// deprecated

+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate identity:(NWIdentityRef)identity error:(NSError **)error __deprecated;
+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate PKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error __deprecated;
- (BOOL)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error __deprecated;
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error __deprecated;

@end
