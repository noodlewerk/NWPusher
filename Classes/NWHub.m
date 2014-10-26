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
    
+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate identity:(NWIdentityRef)identity error:(NSError **)error
{
    NWHub *hub = [[NWHub alloc] initWithDelegate:delegate];
    return identity && [hub connectWithIdentity:identity error:error] ? hub : nil;
}

+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate PKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error
{
    NWHub *hub = [[NWHub alloc] initWithDelegate:delegate];
    return data && [hub connectWithPKCS12Data:data password:password error:error] ? hub : nil;
}

#pragma mark - Pushing without NSError
    
- (NSUInteger)pushPayload:(NSString *)payload token:(NSString *)token
{
    NSUInteger identifier = _index++;
    NWNotification *notification = [[NWNotification alloc] initWithPayload:payload token:token identifier:identifier expiration:nil priority:0];
    return [self pushNotifications:@[notification]];
}

- (NSUInteger)pushPayload:(NSString *)payload tokens:(NSArray *)tokens
{
    NSMutableArray *notifications = @[].mutableCopy;
    for (NSString *token in tokens) {
        NSUInteger identifier = _index++;
        NWNotification *notification = [[NWNotification alloc] initWithPayload:payload token:token identifier:identifier expiration:nil priority:0];
        [notifications addObject:notification];
    }
    return [self pushNotifications:notifications];
}

- (NSUInteger)pushPayloads:(NSArray *)payloads token:(NSString *)token
{
    NSMutableArray *notifications = @[].mutableCopy;
    for (NSString *payload in payloads) {
        NSUInteger identifier = _index++;
        NWNotification *notification = [[NWNotification alloc] initWithPayload:payload token:token identifier:identifier expiration:nil priority:0];
        [notifications addObject:notification];
    }
    return [self pushNotifications:notifications];
}

- (NSUInteger)pushNotifications:(NSArray *)notifications
{
    NSUInteger fails = 0;
    for (NWNotification *notification in notifications) {
        if (!notification.identifier) notification.identifier = _index++;
        BOOL success = [self pushNotification:notification autoReconnect:YES error:nil];
        if (!success) {
            fails++;
        }
    }
    return fails;
}

#pragma mark - Pushing with NSError

- (BOOL)pushNotification:(NWNotification *)notification autoReconnect:(BOOL)reconnect error:(NSError *__autoreleasing *)error
{
    NSError *e = nil;
    BOOL pushed = [_pusher pushNotification:notification type:_type error:&e];
    if (!pushed) {
        if (error) *error = e;
        if ([_delegate respondsToSelector:@selector(notification:didFailWithResult:)]) {
            [_delegate notification:notification didFailWithResult:e.code];
        }
        if ([_delegate respondsToSelector:@selector(notification:didFailWithError:)]) {
            [_delegate notification:notification didFailWithError:e];
        }
        if (reconnect && e.code == kNWErrorWriteClosedGraceful) {
            [self reconnectWithError:error];
        }
        return pushed;
    }
    _notificationForIdentifier[@(notification.identifier)] = @[notification, NSDate.date];
    return YES;
}

- (BOOL)pushNotifications:(NSArray *)notifications autoReconnect:(BOOL)reconnect error:(NSError *__autoreleasing *)error
{
    for (NWNotification *notification in notifications) {
        if (!notification.identifier) notification.identifier = _index++;
        BOOL success = [self pushNotification:notification autoReconnect:reconnect error:error];
        if (!success) {
            return success;
        }
    }
    return YES;
}

#pragma mark - Fetching failed

- (NSUInteger)fetchFailed
{
    NSUInteger count = 0;
    [self fetchFailed:&count max:1000 autoReconnect:YES error:nil];
    return count;
}

- (BOOL)fetchFailed:(NSUInteger *)failed max:(NSUInteger)max autoReconnect:(BOOL)reconnect error:(NSError *__autoreleasing *)error
{
    for (NSUInteger i = 0; i < max; i++) {
        BOOL f = NO;
        BOOL fetched = [self fetchFailed:&f autoReconnect:reconnect error:error];
        if (!fetched) {
            return fetched;
        }
        if (!f) {
            if (failed) *failed = i;
            break;
        }
    }
    [self trimIdentifiers];
    return YES;
}

- (BOOL)fetchFailed:(BOOL *)failed autoReconnect:(BOOL)reconnect error:(NSError *__autoreleasing *)error
{
    NSUInteger identifier = 0;
    NSError *apnError = nil;
    BOOL fetch = [_pusher fetchFailedIdentifier:&identifier apnError:&apnError error:error];
    if (!fetch) {
        return fetch;
    }
    if (failed) *failed = !!apnError;
    if (apnError) {
        NWNotification *notification = _notificationForIdentifier[@(identifier)][0];
        if ([_delegate respondsToSelector:@selector(notification:didFailWithResult:)]) {
            [_delegate notification:notification didFailWithResult:apnError.code];
        }
        if ([_delegate respondsToSelector:@selector(notification:didFailWithError:)]) {
            [_delegate notification:notification didFailWithError:apnError];
        }
        if (reconnect) {
            [self reconnectWithError:error];
        }
    }
    return YES;
}

- (BOOL)trimIdentifiers
{
    NSDate *oldBefore = [NSDate dateWithTimeIntervalSinceNow:-_feedbackSpan];
    NSArray *old = [[_notificationForIdentifier keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return [oldBefore compare:obj[1]] == NSOrderedDescending;
    }] allObjects];
    [_notificationForIdentifier removeObjectsForKeys:old];
    return !!old.count;
}

#pragma mark - Deprecated

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

- (NSUInteger)flushFailed
{
    return [self fetchFailed];
}

- (NSUInteger)pushNotifications:(NSArray *)notifications autoReconnect:(BOOL)reconnect
{
    NSAssert(reconnect, @"autoReconnect == false is ignored");
    return [self pushNotifications:notifications];
}

@end
