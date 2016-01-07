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

@implementation NWPushFeedback

#pragma mark - Connecting

- (BOOL)connectWithIdentity:(NWIdentityRef)identity environment:(NWEnvironment)environment error:(NSError *__autoreleasing *)error
{
    if (_connection) [_connection disconnect]; _connection = nil;
    if (environment == NWEnvironmentAuto) environment = [NWSecTools environmentForIdentity:identity];
    NSString *host = (environment == NWEnvironmentSandbox) ? NWSandboxPushHost : NWPushHost;
    NWSSLConnection *connection = [[NWSSLConnection alloc] initWithHost:host port:NWPushPort identity:identity];
    BOOL connected = [connection connectWithError:error];
    if (!connected) {
        return connected;
    }
    _connection = connection;
    return YES;
}

- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password environment:(NWEnvironment)environment error:(NSError *__autoreleasing *)error
{
    NWIdentityRef identity = [NWSecTools identityWithPKCS12Data:data password:password error:error];
    if (!identity) {
        return NO;
    }
    return [self connectWithIdentity:identity environment:environment error:error];
}

- (void)disconnect
{
    [_connection disconnect]; _connection = nil;
}

+ (instancetype)connectWithIdentity:(NWIdentityRef)identity environment:(NWEnvironment)environment error:(NSError *__autoreleasing *)error
{
    NWPushFeedback *feedback = [[NWPushFeedback alloc] init];
    return identity && [feedback connectWithIdentity:identity environment:environment error:error] ? feedback : nil;
}

+ (instancetype)connectWithPKCS12Data:(NSData *)data password:(NSString *)password environment:(NWEnvironment)environment error:(NSError *__autoreleasing *)error
{
    NWPushFeedback *feedback = [[NWPushFeedback alloc] init];
    return data && [feedback connectWithPKCS12Data:data password:password environment:environment error:error] ? feedback : nil;
}


#pragma mark - Reading feedback

- (BOOL)readTokenData:(NSData **)token date:(NSDate **)date error:(NSError *__autoreleasing *)error
{
    *token = nil;
    *date = nil;
    NSMutableData *data = [NSMutableData dataWithLength:sizeof(uint32_t) + sizeof(uint16_t) + NWTokenMaxSize];
    NSUInteger length = 0;
    BOOL read = [_connection read:data length:&length error:error];
    if (!read || length == 0) {
        return read;
    }
    if (length != data.length) {
        return [NWErrorUtil noWithErrorCode:kNWErrorFeedbackLength reason:length error:error];
    }
    uint32_t time = 0;
    [data getBytes:&time range:NSMakeRange(0, 4)];
    *date = [NSDate dateWithTimeIntervalSince1970:htonl(time)];
    uint16_t l = 0;
    [data getBytes:&l range:NSMakeRange(4, 2)];
    NSUInteger tokenLength = htons(l);
    if (tokenLength != NWTokenMaxSize) {
        return [NWErrorUtil noWithErrorCode:kNWErrorFeedbackTokenLength reason:tokenLength error:error];
    }
    *token = [data subdataWithRange:NSMakeRange(6, length - 6)];
    return YES;
}

- (BOOL)readToken:(NSString **)token date:(NSDate **)date error:(NSError *__autoreleasing *)error
{
    *token = nil;
    NSData *data = nil;
    BOOL read = [self readTokenData:&data date:date error:error];
    if (!read) {
        return read;
    }
    if (data) *token = [NWNotification hexFromData:data];
    return YES;
}

- (NSArray *)readTokenDatePairsWithMax:(NSUInteger)max error:(NSError *__autoreleasing *)error
{
    NSMutableArray *pairs = @[].mutableCopy;
    for (NSUInteger i = 0; i < max; i++) {
        NSString *token = nil;
        NSDate *date = nil;
        NSError *e = nil;
        BOOL read = [self readToken:&token date:&date error:&e];
        if (!read && e.code == kNWErrorReadClosedGraceful) {
            break;
        }
        if (!read) {
            if (error) *error = e;
            return nil;
        }
        if (token && date) {
            [pairs addObject:@[token, date]];
        }
    }
    return pairs;
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

+ (instancetype)connectWithIdentity:(NWIdentityRef)identity error:(NSError *__autoreleasing *)error
{
    return [self connectWithIdentity:identity environment:NWEnvironmentAuto error:error];
}

+ (instancetype)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError *__autoreleasing *)error
{
    return [self connectWithPKCS12Data:data password:password environment:NWEnvironmentAuto error:error];
}

@end
