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

- (NWError)connectWithIdentity:(NWIdentityRef)identity
{
    return [_pusher connectWithIdentity:identity];
}

- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password
{
    return [_pusher connectWithPKCS12Data:data password:password];
}

- (NWError)reconnect
{
    return [_pusher reconnect];
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
        BOOL failed = [self pushNotification:notification autoReconnect:reconnect];
        if (failed) count++;
    }
    return count;
}

- (BOOL)pushNotification:(NWNotification *)notification autoReconnect:(BOOL)reconnect
{
    NWError pushed = [_pusher pushNotification:notification type:_type];
    if (pushed != kNWSuccess) {
        [_delegate notification:notification didFailWithResult:pushed];
    }
    if (reconnect && pushed == kNWErrorWriteClosedGraceful) {
        [self reconnect];
    }
    _notificationForIdentifier[@(notification.identifier)] = @[notification, NSDate.date];
    return pushed != kNWSuccess;
}

- (BOOL)fetchFailed
{
    NSUInteger identifier = 0;
    NWError apnError = kNWSuccess;
    NWError fetch = [_pusher fetchFailedIdentifier:&identifier apnError:&apnError];
    if (fetch != kNWSuccess) {
        return NO;
    }
    if (identifier || apnError != kNWSuccess) {
        NWNotification *notification = _notificationForIdentifier[@(identifier)][0];
        [_delegate notification:notification didFailWithResult:apnError];
        return YES;
    }
    return NO;
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

#pragma mark - Deprecated

#if !TARGET_OS_IPHONE
- (NWError)connectWithCertificateRef:(SecCertificateRef)certificate
{
    NWIdentityRef identity = nil;
    NWError error = [NWSecTools keychainIdentityWithCertificate:(__bridge NWCertificateRef)certificate identity:&identity];
    if (error != kNWSuccess) {
        return error;
    }
    return [self connectWithIdentity:identity];
}
#endif

- (NWError)connectWithIdentityRef:(SecIdentityRef)identity
{
    return [self connectWithIdentity:(__bridge NWIdentityRef)identity];
}

@end
