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

- (NWError)fetchFailedIdentifier:(NSUInteger *)identifier apnError:(NWError *)apnError
{
    *apnError = kNWSuccess;
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
        case 1: *apnError = kNWErrorAPNProcessing; break;
        case 2: *apnError = kNWErrorAPNMissingDeviceToken; break;
        case 3: *apnError = kNWErrorAPNMissingTopic; break;
        case 4: *apnError = kNWErrorAPNMissingPayload; break;
        case 5: *apnError = kNWErrorAPNInvalidTokenSize; break;
        case 6: *apnError = kNWErrorAPNInvalidTopicSize; break;
        case 7: *apnError = kNWErrorAPNInvalidPayloadSize; break;
        case 8: *apnError = kNWErrorAPNInvalidTokenContent; break;
        case 10: *apnError = kNWErrorAPNShutdown; break;
    }
    return kNWSuccess;
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

+ (NSString *)stringFromResult:(NWError)result
{
    return [NWErrorUtil stringWithError:result];
}

- (NWError)fetchFailedIdentifier:(NSUInteger *)identifier
{
    NWError apnError = kNWSuccess;
    NWError result = [self fetchFailedIdentifier:identifier apnError:&apnError];
    if (result != kNWSuccess) {
        return result;
    }
    return apnError;
}

@end
