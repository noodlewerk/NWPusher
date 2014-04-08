//
//  NWPushFeedback.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWPushFeedback.h"
#import "NWSSLConnection.h"
#import "NWSecTools.h"
#import "NWNotification.h"


static NSString * const NWSandboxPushHost = @"feedback.sandbox.push.apple.com";
static NSString * const NWPushHost = @"feedback.push.apple.com";
static NSUInteger const NWPushPort = 2196;
static NSUInteger const NWTokenMaxSize = 32;

@implementation NWPushFeedback {
    NWSSLConnection *_connection;
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

- (void)disconnect
{
    [_connection disconnect]; _connection = nil;
}


#pragma mark - Apple push

- (NWError)readTokenData:(NSData **)token date:(NSDate **)date
{
    *token = nil;
    *date = nil;
    NSMutableData *data = [NSMutableData dataWithLength:sizeof(uint32_t) + sizeof(uint16_t) + NWTokenMaxSize];
    NSUInteger length = 0;
    NWError read = [_connection read:data length:&length];
    if (read != kNWSuccess || length == 0) {
        return read;
    }
    if (length != data.length) {
        return kNWErrorFeedbackLength;
    }
    uint32_t time = 0;
    [data getBytes:&time range:NSMakeRange(0, 4)];
    *date = [NSDate dateWithTimeIntervalSince1970:htonl(time)];
    uint16_t l = 0;
    [data getBytes:&l range:NSMakeRange(4, 2)];
    NSUInteger tokenLength = htons(l);
    if (tokenLength != NWTokenMaxSize) {
        return kNWErrorFeedbackTokenLength;
    }
    *token = [data subdataWithRange:NSMakeRange(6, length - 6)];
    return kNWSuccess;
}

- (NWError)readToken:(NSString **)token date:(NSDate **)date;
{
    *token = nil;
    NSData *data = nil;
    NWError read = [self readTokenData:&data date:date];
    if (read != kNWSuccess) {
        return read;
    }
    if (data) *token = [NWNotification hexFromData:data];
    return read;
}

- (NWError)readTokenDatePairs:(NSArray **)pairs max:(NSUInteger)max
{
    NSMutableArray *all = @[].mutableCopy;
    *pairs = all;
    for (NSUInteger i = 0; i < max; i++) {
        NSString *token = nil;
        NSDate *date = nil;
        NWError read = [self readToken:&token date:&date];
        if (read == kNWErrorReadClosedGraceful) {
            break;
        }
        if (read != kNWSuccess) {
            return read;
        }
        if (token && date) {
            [all addObject:@[token, date]];
        }
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

@end
