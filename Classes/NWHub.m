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

- (BOOL)connectWithIdentity:(NWIdentityRef)identity environment:(NWEnvironment)environment error:(NSError *__autoreleasing *)error
{
    return [_pusher connectWithIdentity:identity environment:environment error:error];
}

- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password environment:(NWEnvironment)environment error:(NSError *__autoreleasing *)error
{
    return [_pusher connectWithPKCS12Data:data password:password environment:environment error:error];
}

- (BOOL)reconnectWithError:(NSError *__autoreleasing *)error
{
    return [_pusher reconnectWithError:error];
}

- (void)disconnect
{
    [_pusher disconnect];
}
    
+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate identity:(NWIdentityRef)identity environment:(NWEnvironment)environment error:(NSError *__autoreleasing *)error
{
    NWHub *hub = [[NWHub alloc] initWithDelegate:delegate];
    return identity && [hub connectWithIdentity:identity environment:environment error:error] ? hub : nil;
}

+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate PKCS12Data:(NSData *)data password:(NSString *)password environment:(NWEnvironment)environment error:(NSError *__autoreleasing *)error
{
    NWHub *hub = [[NWHub alloc] initWithDelegate:delegate];
    return data && [hub connectWithPKCS12Data:data password:password environment:environment error:error] ? hub : nil;
}

#pragma mark - Pushing without NSError
    
- (NSUInteger)pushPayload:(NSString *)payload token:(NSString *)token
{
    NWNotification *notification = [[NWNotification alloc] initWithPayload:payload token:token identifier:0 expiration:nil priority:0];
    return [self pushNotifications:@[notification]];
}

- (NSUInteger)pushPayload:(NSString *)payload tokens:(NSArray *)tokens
{
    NSMutableArray *notifications = @[].mutableCopy;
    for (NSString *token in tokens) {
        NWNotification *notification = [[NWNotification alloc] initWithPayload:payload token:token identifier:0 expiration:nil priority:0];
        [notifications addObject:notification];
    }
    return [self pushNotifications:notifications];
}

- (NSUInteger)pushPayloads:(NSArray *)payloads token:(NSString *)token
{
    NSMutableArray *notifications = @[].mutableCopy;
    for (NSString *payload in payloads) {
        NWNotification *notification = [[NWNotification alloc] initWithPayload:payload token:token identifier:0 expiration:nil priority:0];
        [notifications addObject:notification];
    }
    return [self pushNotifications:notifications];
}

- (NSUInteger)pushNotifications:(NSArray *)notifications
{
    NSUInteger fails = 0;
    for (NWNotification *notification in notifications) {
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
    if (!notification.identifier) notification.identifier = _index++;
    NSError *e = nil;
    BOOL pushed = [_pusher pushNotification:notification type:_type error:&e];
    if (!pushed) {
        if (error) *error = e;
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
        BOOL success = [self pushNotification:notification autoReconnect:reconnect error:error];
        if (!success) {
            return success;
        }
    }
    return YES;
}

#pragma mark - Reading failed

- (NSUInteger)readFailed
{
    NSArray *failed = nil;
    [self readFailed:&failed max:1000 autoReconnect:YES error:nil];
    return failed.count;
}

- (BOOL)readFailed:(NSArray **)notifications max:(NSUInteger)max autoReconnect:(BOOL)reconnect error:(NSError *__autoreleasing *)error
{
    NSMutableArray *n = @[].mutableCopy;
    for (NSUInteger i = 0; i < max; i++) {
        NWNotification *notification = nil;
        BOOL read = [self readFailed:&notification autoReconnect:reconnect error:error];
        if (!read) {
            return read;
        }
        if (!notification) {
            break;
        }
        [n addObject:notification];
    }
    if (notifications) *notifications = n;
    [self trimIdentifiers];
    return YES;
}

- (BOOL)readFailed:(NWNotification **)notification autoReconnect:(BOOL)reconnect error:(NSError *__autoreleasing *)error
{
    NSUInteger identifier = 0;
    NSError *apnError = nil;
    BOOL read = [_pusher readFailedIdentifier:&identifier apnError:&apnError error:error];
    if (!read) {
        return read;
    }
    if (apnError) {
        NWNotification *n = _notificationForIdentifier[@(identifier)][0];
        if (notification) *notification = n ?: (NWNotification *)NSNull.null;
        if ([_delegate respondsToSelector:@selector(notification:didFailWithError:)]) {
            [_delegate notification:n didFailWithError:apnError];
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

- (BOOL)connectWithIdentity:(NWIdentityRef)identity error:(NSError *__autoreleasing *)error
{
    return [self connectWithIdentity:identity environment:NWEnvironmentAuto error:error];
}

- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError *__autoreleasing *)error
{
    return [self connectWithPKCS12Data:data password:password environment:NWEnvironmentAuto error:error];
}

+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate identity:(NWIdentityRef)identity error:(NSError *__autoreleasing *)error
{
    return [self connectWithDelegate:delegate identity:identity environment:NWEnvironmentAuto error:error];
}

+ (instancetype)connectWithDelegate:(id<NWHubDelegate>)delegate PKCS12Data:(NSData *)data password:(NSString *)password error:(NSError *__autoreleasing *)error
{
    return [self connectWithDelegate:delegate identity:data environment:NWEnvironmentAuto error:error];
}

@end
