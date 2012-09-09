//
//  NWPusher.m
//  Pusher
//
//  Created by Leo on 9/9/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWPusher.h"
#import "NWSSLConnection.h"
#import "NWSecTools.h"


// http://developer.apple.com/library/mac/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingWIthAPS/CommunicatingWIthAPS.html

static NSString * const NWSandboxPushHost = @"gateway.sandbox.push.apple.com";
static NSString * const NWPushHost = @"gateway.push.apple.com";
static NSUInteger const NWPushPort = 2195;
static NSUInteger const NWDeviceTokenSize = 32;
static NSUInteger const NWPayloadMaxSize = 256;

@implementation NWPusher {
    NWSSLConnection *connection;
}


#pragma mark - Apple SSL

- (BOOL)connectWithCertificateRef:(SecCertificateRef)certificate sandbox:(BOOL)sandbox
{
    SecIdentityRef identity = NULL;
    BOOL result = [NWSecTools identityWithCertificateRef:certificate identity:&identity];
    if (!result) {
        return NO;
    }
    result = [self connectWithIdentityRef:identity sandbox:sandbox];
    CFRelease(identity);
    return result;
}

- (BOOL)connectWithIdentityRef:(SecIdentityRef)identity sandbox:(BOOL)sandbox
{
    NSString *host = sandbox ? NWSandboxPushHost : NWPushHost;
    
    if (connection) [connection disconnect];
    connection = [[NWSSLConnection alloc] initWithHost:host port:NWPushPort identity:identity];
    
    BOOL result = [connection connect];
    return result;
}

- (void)disconnect
{
    [connection disconnect]; connection = nil;
}


#pragma mark - Apple push

- (BOOL)pushPayloadString:(NSString *)payload token:(NSString *)token
{
    BOOL result = [self pushPayloadString:payload token:token identifier:0 expires:NULL];
    return result;
}

- (BOOL)pushPayloadString:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier expires:(NSDate *)expires
{
    if (!payload.length) {
        NWLogWarn(@"Payload is empty");
        return NO;
    }
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSDictionary *payloadDict = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:&error];
    NWLogWarnIfError(error);
    if (!payloadDict.count) {
        NWLogWarn(@"Invalid payload format");
        return NO;
    }
    
    if (!token.length) {
        NWLogWarn(@"Device token is emtpy");
        return NO;
    }
    NSString *normal = [self.class filterHex:token];
    NSUInteger max = NWDeviceTokenSize * 2;
    NSString *trunk = normal.length >= max ? [normal substringToIndex:max] : nil;
    NSData *tokenData = [self.class dataFromHex:trunk];
    if (!tokenData.length) {
        NWLogWarn(@"Unable to read device token");
        return NO;
    }
    
    BOOL result = [self pushPayloadData:payloadData tokenData:tokenData identifier:identifier expires:expires];
    return result;
}

- (BOOL)pushPayloadData:(NSData *)payload tokenData:(NSData *)token
{
    BOOL result = [self pushPayloadData:payload tokenData:token enhance:NO identifier:0 expires:nil];
    return result;
}

- (BOOL)pushPayloadData:(NSData *)payload tokenData:(NSData *)token identifier:(NSUInteger)identifier expires:(NSDate *)expires
{
    BOOL result = [self pushPayloadData:payload tokenData:token enhance:YES identifier:identifier expires:expires];
    return result;
}

- (BOOL)pushPayloadData:(NSData *)payload tokenData:(NSData *)token enhance:(BOOL)enhance identifier:(NSUInteger)identifier expires:(NSDate *)expires
{
    if (token.length != NWDeviceTokenSize) {
        NWLogWarn(@"Invalid device token specified (%i hex characters)", (int)NWDeviceTokenSize * 2);
        return NO;
    }
    if (payload.length > NWPayloadMaxSize) {
        NWLogWarn(@"Payload cannot be more than %i bytes (UTF8)", (int)NWPayloadMaxSize);
        return NO;
    }
    
    char buffer[sizeof(uint8_t) + sizeof(uint32_t) * 2 + sizeof(uint16_t) + NWDeviceTokenSize + sizeof(uint16_t) + NWPayloadMaxSize];
    char *p = buffer;
    
    uint8_t command = enhance ? 1 : 0;
    memcpy(p, &command, sizeof(uint8_t));
    p += sizeof(uint8_t);
    
    if (enhance) {
        uint32_t ID = htonl(identifier);
        memcpy(p, &ID, sizeof(uint32_t));
        p += sizeof(uint32_t);
        
        uint32_t exp = htonl((NSUInteger)expires.timeIntervalSince1970);
        memcpy(p, &exp, sizeof(uint32_t));
        p += sizeof(uint32_t);
    }
    
    uint16_t tokenLength = htons(token.length);
    memcpy(p, &tokenLength, sizeof(uint16_t));
    p += sizeof(uint16_t);
    
    memcpy(p, token.bytes, token.length);
    p += token.length;
    
    uint16_t payloadLength = htons(payload.length);
    memcpy(p, &payloadLength, sizeof(uint16_t));
    p += sizeof(uint16_t);
    
    memcpy(p, payload.bytes, payload.length);
    p += payload.length;
    
    NSData *data = [NSData dataWithBytes:buffer length:p - buffer];
    BOOL result = [connection write:data length:NULL];
    
    return result;
}

- (BOOL)fetchFailedIdentifier:(NSUInteger *)identifier reason:(NSString **)reason
{
    NSMutableData *data = [NSMutableData dataWithLength:sizeof(uint8_t) * 2 + sizeof(uint32_t)];
    NSUInteger length = 0;
    BOOL read = [connection read:data length:&length];
    if (!read) {
        return NO;
    }
    
    if (length) {
        uint8_t command = 0;
        [data getBytes:&command range:NSMakeRange(0, 1)];
        if (command != 8) {
            NWLogWarn(@"Unexpected response command: %i", command);
            return NO;
        }
        if (length != data.length) {
            NWLogWarn(@"Unexpected response length: %@", data);
            return NO;
        }
        uint8_t status = 0;
        [data getBytes:&status range:NSMakeRange(1, 1)];
        uint32_t ID = 0;
        [data getBytes:&ID range:NSMakeRange(2, 4)];
        if (identifier) *identifier = htonl(ID);
        if (reason) {
            switch (status) {
                case 0: *reason = @"No errors encountered"; break;
                case 1: *reason = @"Processing error"; break;
                case 2: *reason = @"Missing device token"; break;
                case 3: *reason = @"Missing topic"; break;
                case 4: *reason = @"Missing payload"; break;
                case 5: *reason = @"Invalid token size"; break;
                case 6: *reason = @"Invalid topic size"; break;
                case 7: *reason = @"Invalid payload size"; break;
                case 8: *reason = @"Invalid token"; break;
                default: *reason = [NSString stringWithFormat:@"Unknown error encountered (%i)", status]; break;
            }
        }
    }
    
    return YES;
}


#pragma mark - Helpers

+ (NSString *)filterHex:(NSString *)hex
{
    hex = hex.lowercaseString;
    NSMutableString *result = [[NSMutableString alloc] init];
    for (NSUInteger i = 0; i < hex.length; i++) {
        unichar c = [hex characterAtIndex:i];
        if ((c >= 'a' && c <= 'f') || (c >= '0' && c <= '9')) {
            [result appendString:[NSString stringWithCharacters:&c length:1]];
        }
    }
    return result;
}

+ (NSData *)dataFromHex:(NSString *)hex
{
    NSMutableData *result = [[NSMutableData alloc] init];
    char buffer[3] = {'\0','\0','\0'};
    for (NSUInteger i = 0; i < hex.length / 2; i++) {
        buffer[0] = [hex characterAtIndex:i * 2];
        buffer[1] = [hex characterAtIndex:i * 2 + 1];
        unsigned char b = strtol(buffer, NULL, 16);
        [result appendBytes:&b length:1];
    }
    return result;
}

@end