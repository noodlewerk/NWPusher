//
//  NWPusher.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWPusher.h"
#import "NWSSLConnection.h"
#import "NWSecTools.h"
#import "NWNotification.h"


static NSString * const NWSandboxPushHost = @"gateway.sandbox.push.apple.com";
static NSString * const NWPushHost = @"gateway.push.apple.com";
static NSUInteger const NWPushPort = 2195;

@implementation NWPusher {
    NSUInteger _index;
}


#pragma mark - Apple SSL

- (NWError)connectWithIdentity:(NWIdentityRef)identity
{
    if (_connection) [_connection disconnect]; _connection = nil;
    NSString *host = [NWSecTools isSandboxIdentity:identity] ? NWSandboxPushHost : NWPushHost;
    NWSSLConnection *connection = [[NWSSLConnection alloc] initWithHost:host port:NWPushPort identity:identity];
    NWError result = [connection connect];
    if (result == kNWSuccess) {
        _connection = connection;
    }
    return result;
}

- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password
{
    NWIdentityRef identity = nil;
    NWError result = [NWSecTools identityWithPKCS12Data:data password:password identity:&identity];
    if (result != kNWSuccess) {
        return result;
    }
    return [self connectWithIdentity:identity];
}

- (NWError)reconnect
{
    if (!_connection) {
        return kNWErrorPushNotConnected;
    }
    return [_connection connect];
}

- (void)disconnect
{
    [_connection disconnect]; _connection = nil;
}


#pragma mark - Apple push

- (NWError)pushPayload:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier
{
    return [self pushNotification:[[NWNotification alloc] initWithPayload:payload token:token identifier:identifier expiration:nil priority:0] type:kNWNotificationType2];
}

- (NWError)pushNotification:(NWNotification *)notification type:(NWNotificationType)type
{
    NSUInteger length = 0;
    NSData *data = [notification dataWithType:type];
    NWError result = [_connection write:data length:&length];
    if (result != kNWSuccess) {
        return result;
    }
    if (length != data.length) {
        return kNWErrorPushWriteFail;
    }
    return kNWSuccess;
}

- (NWError)fetchFailedIdentifier:(NSUInteger *)identifier
{
    *identifier = 0;
    NSMutableData *data = [NSMutableData dataWithLength:sizeof(uint8_t) * 2 + sizeof(uint32_t)];
    NSUInteger length = 0;
    NWError read = [_connection read:data length:&length];
    if (!length || read != kNWSuccess) {
        return read;
    }
    uint8_t command = 0;
    [data getBytes:&command range:NSMakeRange(0, 1)];
    if (command != 8) {
        return kNWErrorPushResponseCommand;
    }
    uint8_t status = 0;
    [data getBytes:&status range:NSMakeRange(1, 1)];
    uint32_t ID = 0;
    [data getBytes:&ID range:NSMakeRange(2, 4)];
    *identifier = htonl(ID);
    switch (status) {
        case 0: return kNWSuccess;
        case 1: return kNWErrorAPNProcessing;
        case 2: return kNWErrorAPNMissingDeviceToken;
        case 3: return kNWErrorAPNMissingTopic;
        case 4: return kNWErrorAPNMissingPayload;
        case 5: return kNWErrorAPNInvalidTokenSize;
        case 6: return kNWErrorAPNInvalidTopicSize;
        case 7: return kNWErrorAPNInvalidPayloadSize;
        case 8: return kNWErrorAPNInvalidTokenContent;
        case 10: return kNWErrorAPNShutdown;
    }
    return kNWErrorAPNUnknownReason;
}

#pragma mark - Deprecated

#if !TARGET_OS_IPHONE
- (NWError)connectWithCertificateRef:(SecCertificateRef)certificate __attribute__((deprecated))
{
    NWIdentityRef identity = nil;
    NWError error = [NWSecTools keychainIdentityWithCertificate:(__bridge NWCertificateRef)certificate identity:&identity];
    if (error != kNWSuccess) {
        return error;
    }
    return [self connectWithIdentity:identity];
}
#endif

- (NWError)connectWithIdentityRef:(SecIdentityRef)identity __attribute__((deprecated))
{
    return [self connectWithIdentity:(__bridge NWIdentityRef)identity];
}

+ (NSString *)stringFromResult:(NWError)result __attribute__((deprecated))
{
    return [NWErrorUtil stringWithError:result];
}

@end
