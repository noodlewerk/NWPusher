//
//  NWHub.m
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import "NWHub.h"
#import "NWPusher.h"
#import "NWNotification.h"

@implementation NWHub {
    NSUInteger _index;
    NSMutableDictionary *_notificationForIdentifier;
}
    
- (id)init
{
    return [self initWithPusher:[[NWPusher alloc] init] delegate:nil];
}

- (id)initWithDelegate:(id<NWHubDelegate>)delegate
{
    return [self initWithPusher:[[NWPusher alloc] init] delegate:delegate];
}
    
- (id)initWithPusher:(NWPusher *)pusher delegate:(id<NWHubDelegate>)delegate
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

#if !TARGET_OS_IPHONE
- (NWPusherResult)connectWithCertificateRef:(SecCertificateRef)certificate
{
    return [_pusher connectWithCertificateRef:certificate];
}
#endif
    
- (NWPusherResult)connectWithIdentityRef:(SecIdentityRef)identity
{
    return [_pusher connectWithIdentityRef:identity];
}

- (NWPusherResult)connectWithPKCS12Data:(NSData *)data password:(NSString *)password
{
    return [_pusher connectWithPKCS12Data:data password:password];
}

- (NWPusherResult)reconnect
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
    NWPusherResult pushed = [_pusher pushNotification:notification type:_type];
    if (pushed != kNWPusherResultSuccess) {
        [_delegate notification:notification didFailWithResult:pushed];
    }
    if (reconnect && pushed == kNWPusherResultIOWriteConnectionClosed) {
        [self reconnect];
    }
    _notificationForIdentifier[@(notification.identifier)] = @[notification, NSDate.date];
    return pushed != kNWPusherResultSuccess;
}

- (BOOL)fetchFailed
{
    NSUInteger identifier = 0;
    NWPusherResult failed = [_pusher fetchFailedIdentifier:&identifier];
    if (!identifier) return NO;
    NWNotification *notification = _notificationForIdentifier[@(identifier)][0];
    [_delegate notification:notification didFailWithResult:failed];
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

@end
