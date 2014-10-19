//
//  NWHub.m
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import "NWHub.h"
#import "NWPusher.h"
#import "NWNotification.h"
#import "NWSecTools.h"


@implementation NWHub {
    NSUInteger _index;
    NSMutableDictionary *_notificationForIdentifier;
}
    
- (instancetype)init
{
    return [self initWithPusher:[[NWPusher alloc] init] delegate:nil];
}

- (instancetype)initWithDelegate:(id<NWHubDelegate>)delegate
{
    return [self initWithPusher:[[NWPusher alloc] init] delegate:delegate];
}
    
- (instancetype)initWithPusher:(NWPusher *)pusher delegate:(id<NWHubDelegate>)delegate
{
    self = [super init];
    if (self) {
        _index = 1;
        _feedbackSpan = 30;
        _pusher = pusher;
        _delegate = delegate;
        _notificationForIdentifier = @{}.mutableCopy;
        _type = kNWNotificationType2;
    }
    return self;
}
    
    
#pragma mark - Connecting

- (BOOL)connectWithIdentity:(NWIdentityRef)identity error:(NSError *__autoreleasing *)error
{
    return [_pusher connectWithIdentity:identity error:error];
}

- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError *__autoreleasing *)error
{
    return [_pusher connectWithPKCS12Data:data password:password error:error];
}

- (BOOL)reconnectWithError:(NSError *__autoreleasing *)error
{
    return [_pusher reconnectWithError:error];
}

- (void)disconnect
{
    [_pusher disconnect];
}
    

#pragma mark - Pushing
    
- (NSUInteger)pushPayload:(NSString *)payload token:(NSString *)token
{
    NSUInteger identifier = _index++;
    NWNotification *notification = [[NWNotification alloc] initWithPayload:payload token:token identifier:identifier expiration:nil priority:0];
    return [self pushNotifications:@[notification] autoReconnect:NO];
}

- (NSUInteger)pushPayload:(NSString *)payload tokens:(NSArray *)tokens
{
    NSMutableArray *notifications = @[].mutableCopy;
    for (NSString *token in tokens) {
        NSUInteger identifier = _index++;
        NWNotification *notification = [[NWNotification alloc] initWithPayload:payload token:token identifier:identifier expiration:nil priority:0];
        [notifications addObject:notification];
    }
    return [self pushNotifications:notifications autoReconnect:NO];
}

- (NSUInteger)pushPayloads:(NSArray *)payloads token:(NSString *)token
{
    NSMutableArray *notifications = @[].mutableCopy;
    for (NSString *payload in payloads) {
        NSUInteger identifier = _index++;
        NWNotification *notification = [[NWNotification alloc] initWithPayload:payload token:token identifier:identifier expiration:nil priority:0];
        [notifications addObject:notification];
    }
    return [self pushNotifications:notifications autoReconnect:NO];
}

- (NSUInteger)pushNotifications:(NSArray *)notifications autoReconnect:(BOOL)reconnect
{
    NSUInteger count = 0;
    for (NWNotification *notification in notifications) {
        if (!notification.identifier) notification.identifier = _index++;
        BOOL success = [self pushNotification:notification autoReconnect:reconnect error:nil];
        if (!success) count++;
    }
    return count;
}

- (BOOL)pushNotification:(NWNotification *)notification autoReconnect:(BOOL)reconnect error:(NSError *__autoreleasing *)error
{
    NSError *e = nil;
    BOOL pushed = [_pusher pushNotification:notification type:_type error:&e];
    if (!pushed) {
        if ([_delegate respondsToSelector:@selector(notification:didFailWithResult:)]) {
            [_delegate notification:notification didFailWithResult:e.code];
        }
        if ([_delegate respondsToSelector:@selector(notification:didFailWithError:)]) {
            [_delegate notification:notification didFailWithError:e];
        }
    }
    if (reconnect && !pushed && e.code == kNWErrorWriteClosedGraceful) {
        [self reconnectWithError:error];
    } else {
        if (error) *error = e;
    }
    _notificationForIdentifier[@(notification.identifier)] = @[notification, NSDate.date];
    return pushed;
}

- (BOOL)fetchFailed
{
    NSUInteger identifier = 0;
    NSError *apnError = nil;
    BOOL fetch = [_pusher fetchFailedIdentifier:&identifier apnError:&apnError error:nil];
    if (!fetch) {
        return fetch;
    }
    if (!identifier && !apnError) {
        return NO;
    }
    NWNotification *notification = _notificationForIdentifier[@(identifier)][0];
    if ([_delegate respondsToSelector:@selector(notification:didFailWithResult:)]) {
        [_delegate notification:notification didFailWithResult:apnError.code];
    }
    if ([_delegate respondsToSelector:@selector(notification:didFailWithError:)]) {
        [_delegate notification:notification didFailWithError:apnError];
    }
    return YES;
}

- (NSUInteger)collectGarbage
{
    NSDate *oldBefore = [NSDate dateWithTimeIntervalSinceNow:-_feedbackSpan];
    NSArray *old = [[_notificationForIdentifier keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return [oldBefore compare:obj[1]] == NSOrderedDescending;
    }] allObjects];
    [_notificationForIdentifier removeObjectsForKeys:old];
    return old.count;
}

- (NSUInteger)flushFailed
{
    NSUInteger count = 0;
    for (BOOL failed = YES; failed; count++) {
        failed = [self fetchFailed];
    }
    [self collectGarbage];
    return count - 1;
}

// deprecated

- (NWError)connectWithIdentity:(NWIdentityRef)identity
{
    NSError *error = nil;
    return [self connectWithIdentity:identity error:&error] ? kNWSuccess : error.code;
}

- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password
{
    NSError *error = nil;
    return [self connectWithPKCS12Data:data password:password error:&error] ? kNWSuccess : error.code;
}

- (NWError)reconnect
{
    NSError *error = nil;
    return [self reconnectWithError:&error] ? kNWSuccess : error.code;
}

@end
