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

- (NSUInteger)pushPayload:(NSString *)payload token:(NSString *)token
{
    NSUInteger identifier = _index++;
    NWNotification *notification = [[NWNotification alloc] initWithPayloadString:payload tokenString:token identifier:identifier expirationDate:nil priority:0];
    return [self pushNotifications:@[notification]];
}

- (NSUInteger)pushPayload:(NSString *)payload tokens:(NSArray *)tokens
{
    NSMutableArray *notifications = @[].mutableCopy;
    for (NSString *token in tokens) {
        NSUInteger identifier = _index++;
        NWNotification *notification = [[NWNotification alloc] initWithPayloadString:payload tokenString:token identifier:identifier expirationDate:nil priority:0];
        [notifications addObject:notification];
    }
    return [self pushNotifications:notifications];
}

- (NSUInteger)pushPayloads:(NSArray *)payloads token:(NSString *)token
{
    NSMutableArray *notifications = @[].mutableCopy;
    for (NSString *payload in payloads) {
        NSUInteger identifier = _index++;
        NWNotification *notification = [[NWNotification alloc] initWithPayloadString:payload tokenString:token identifier:identifier expirationDate:nil priority:0];
        [notifications addObject:notification];
    }
    return [self pushNotifications:notifications];
}

- (NSUInteger)pushNotifications:(NSArray *)notifications
{
    NSUInteger count = 0;
    for (NWNotification *notification in notifications) {
        if (!notification.identifier) notification.identifier = _index++;
        BOOL failed = [self pushNotification:notification];
        if (failed) count++;
    }
    return count;
}

- (BOOL)pushNotification:(NWNotification *)notification
{
    NWPusherResult pushed = [_pusher pushNotification:notification type:_type];
    if (pushed != kNWPusherResultSuccess) {
        [_delegate notification:notification didFailWithResult:pushed];
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

- (NWPusherResult)reconnect
{
    return [_pusher reconnect];
}

- (void)disconnect
{
    [_pusher disconnect];
}

@end
